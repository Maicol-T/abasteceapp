"""Valida el esquema v3 de AbasteceApp con el motor real de SQLite.

El proyecto no puede abrir SQLite en `flutter test` (sqflite es un plugin), así
que esta verificación independiente:

1. Extrae de `lib/database/database_helper.dart` los `CREATE TABLE` reales.
2. Crea la base v3 en memoria y comprueba las columnas de sincronización, sus
   valores por defecto y los índices.
3. Reconstruye una base v2 (sin las columnas nuevas), le inserta filas con
   `is_synced` 0 y 1, aplica la migración v3 y verifica que:
   * las columnas se agregan una sola vez (idempotente),
   * los registros ya enviados quedan `synced`,
   * los pendientes siguen en `pending`,
   * la cola se puede contar, marcar `failed` y reintentar.

Uso:  python tool/verify_schema_v3.py
"""

from __future__ import annotations

import pathlib
import re
import sqlite3
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
HELPER = ROOT / "lib" / "database" / "database_helper.dart"
SYNC_MODEL = ROOT / "lib" / "models" / "sync_status.dart"

SYNC_COLUMNS = (
    "sync_status",
    "synced_at",
    "sync_error",
    "sync_attempts",
    "updated_at",
)

results: list[tuple[bool, str]] = []


def check(condition: bool, message: str) -> None:
    results.append((bool(condition), message))
    print(("PASS" if condition else "FAIL"), "-", message)


def read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def entity_tables() -> list[str]:
    """Tablas declaradas en el enum SyncEntity."""
    source = read(SYNC_MODEL)
    section = source.split("enum SyncEntity {", 1)[1].split(";", 1)[0]
    entries = re.findall(r"(\w+)\('(\w+)',\s*'([^']*)'\)", section)
    return [table for _, table, _ in entries]


def create_blocks() -> dict[str, str]:
    """DDL de creación de cada tabla (solo el esquema nuevo, sin IF NOT EXISTS)."""
    source = read(HELPER)
    blocks: dict[str, str] = {}
    for match in re.finditer(
        r"CREATE TABLE (\w+) \(([\s\S]*?)\n      \)", source
    ):
        name, body = match.group(1), match.group(2)
        blocks.setdefault(name, f"CREATE TABLE {name} ({body}\n)")
    return blocks


def without_sync_columns(block: str) -> str:
    """Convierte el DDL v3 en el DDL v2 equivalente (sin columnas de sync)."""
    pattern = re.compile(
        r"\s*(sync_status|synced_at|sync_error|sync_attempts|updated_at)\s"
    )
    lines = [line for line in block.splitlines() if not pattern.match(line)]
    text = "\n".join(lines)
    # Quita la coma que queda colgando antes del cierre del paréntesis.
    return re.sub(r",(\s*\n\s*)\)", r"\1)", text)


def table_info(connection: sqlite3.Connection, table: str) -> dict[str, tuple]:
    return {
        row[1]: row for row in connection.execute(f"PRAGMA table_info({table})")
    }


def ensure_column(
    connection: sqlite3.Connection, table: str, column: str, definition: str
) -> None:
    """Equivalente a DatabaseHelper._ensureColumn (idempotente)."""
    if column in table_info(connection, table):
        return
    connection.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")


def main() -> int:
    tables = entity_tables()
    blocks = create_blocks()

    check(len(tables) == 7, f"SyncEntity declara 7 tablas ({len(tables)})")
    for table in tables:
        check(table in blocks, f"DDL encontrado para {table}")

    # ------------------------------------------------------------------ v3
    fresh = sqlite3.connect(":memory:")
    for table in tables:
        fresh.execute(blocks[table])
    for table in tables:
        fresh.execute(
            f"CREATE INDEX IF NOT EXISTS idx_{table}_sync "
            f"ON {table} (sync_status)"
        )

    for table in tables:
        info = table_info(fresh, table)
        for column in SYNC_COLUMNS:
            check(column in info, f"v3 · {table} tiene {column}")
        definition = info["sync_status"][4]
        check(
            definition == "'pending'",
            f"v3 · {table}.sync_status nace en 'pending' ({definition})",
        )

    # Un pedido insertado sin sync_status queda en la cola.
    fresh.execute(
        "INSERT INTO orders (provider_id, created_at, is_synced) "
        "VALUES (1, '2026-01-01T08:00:00.000', 0)"
    )
    status = fresh.execute("SELECT sync_status FROM orders").fetchone()[0]
    check(status == "pending", "v3 · el pedido nuevo nace pendiente")

    # El índice de la cola existe y lo usa una búsqueda por estado.
    index_names = {
        row[1] for row in fresh.execute("PRAGMA index_list('orders')")
    }
    check("idx_orders_sync" in index_names, "v3 · idx_orders_sync existe")
    plan = " ".join(
        str(row)
        for row in fresh.execute(
            "EXPLAIN QUERY PLAN SELECT COUNT(*) FROM orders "
            "WHERE sync_status = 'pending'"
        )
    )
    check("idx_orders_sync" in plan, "v3 · la consulta de cola usa el índice")

    # Estatus válidos y conteo.
    fresh.execute(
        "UPDATE orders SET sync_status = 'synced', "
        "synced_at = '2026-01-01T09:00:00.000' WHERE id = 1"
    )
    fresh.execute(
        "INSERT INTO orders (provider_id, created_at, is_synced) "
        "VALUES (2, '2026-01-02T08:00:00.000', 1)"
    )
    pending = fresh.execute(
        "SELECT COUNT(*) FROM orders WHERE sync_status <> 'synced'"
    ).fetchone()[0]
    check(pending == 1, "v3 · la cola solo cuenta lo no sincronizado")

    # ------------------------------------------------------------------ v2
    legacy = sqlite3.connect(":memory:")
    for table in tables:
        legacy.execute(without_sync_columns(blocks[table]))

    # Datos heredados: un pedido y una venta ya enviados, otro sin enviar.
    legacy.execute(
        "INSERT INTO orders (provider_id, created_at, is_synced) "
        "VALUES (1, '2025-12-01T08:00:00.000', 1)"
    )
    legacy.execute(
        "INSERT INTO orders (provider_id, created_at, is_synced) "
        "VALUES (2, '2025-12-02T08:00:00.000', 0)"
    )
    legacy.execute(
        "INSERT INTO sales (product_name, created_at, is_synced) "
        "VALUES ('Arroz 500 g', '2025-12-01T08:00:00.000', 1)"
    )
    legacy.execute(
        "INSERT INTO products (name, wholesale_price, stock_quantity) "
        "VALUES ('Aceite 1 L', 9000, 12)"
    )
    legacy.execute(
        "INSERT INTO debts (client_name, amount, date) "
        "VALUES ('Doña Rosa', 15000, '2025-12-01T08:00:00.000')"
    )
    legacy.execute(
        "INSERT INTO stores (user_id, owner_name, id_document, business_name, "
        "address, zone, created_at) VALUES "
        "(1, 'María', '1130456789', 'Tienda Doña María', 'Calle 12', "
        "'Bellavista', '2025-11-01T08:00:00.000')"
    )
    legacy.execute(
        "INSERT INTO suppliers (name) VALUES ('Bodega La Libertad')"
    )
    legacy.execute(
        "INSERT INTO data_consent_logs (user_id, policy_version, timestamp) "
        "VALUES (1, '2.0.0', '2025-11-01T08:00:00.000')"
    )

    legacy_v2_columns = table_info(legacy, "orders")
    check(
        "sync_status" not in legacy_v2_columns,
        "v2 · la base heredada no tiene sync_status",
    )

    # Migración v3 (idempotente: se ejecuta dos veces).
    definitions = (
        ("sync_status", "TEXT NOT NULL DEFAULT 'pending'"),
        ("synced_at", "TEXT"),
        ("sync_error", "TEXT"),
        ("sync_attempts", "INTEGER NOT NULL DEFAULT 0"),
        ("updated_at", "TEXT"),
    )
    for _ in range(2):
        for table in tables:
            for column, definition in definitions:
                ensure_column(legacy, table, column, definition)

    for table in ("orders", "sales"):
        legacy.execute(
            f"UPDATE {table} SET sync_status = 'synced', "
            "synced_at = COALESCE(synced_at, created_at) "
            "WHERE is_synced = 1 AND sync_status = 'pending'"
        )
        legacy.execute(
            f"UPDATE {table} SET updated_at = COALESCE(updated_at, created_at)"
        )
    for table in tables:
        legacy.execute(
            f"CREATE INDEX IF NOT EXISTS idx_{table}_sync "
            f"ON {table} (sync_status)"
        )

    for table in tables:
        info = table_info(legacy, table)
        missing = [column for column in SYNC_COLUMNS if column not in info]
        check(not missing, f"v3 sobre v2 · {table} migrada ({missing})")

    migrated = legacy.execute(
        "SELECT id, sync_status, synced_at FROM orders ORDER BY id"
    ).fetchall()
    check(
        migrated[0][1] == "synced" and migrated[0][2] is not None,
        "v3 sobre v2 · el pedido ya enviado no vuelve a la cola",
    )
    check(
        migrated[1][1] == "pending",
        "v3 sobre v2 · el pedido pendiente sigue en la cola",
    )
    sale = legacy.execute(
        "SELECT sync_status FROM sales WHERE id = 1"
    ).fetchone()[0]
    check(sale == "synced", "v3 sobre v2 · la venta enviada queda sincronizada")

    for table in ("products", "debts", "stores", "suppliers", "data_consent_logs"):
        status = legacy.execute(
            f"SELECT sync_status FROM {table} LIMIT 1"
        ).fetchone()[0]
        check(
            status == "pending",
            f"v3 sobre v2 · {table} heredado entra a la cola",
        )

    # Reintento: failed conserva el error y suma intentos.
    legacy.execute(
        "UPDATE orders SET sync_status = 'failed', sync_error = 'timeout' "
        "WHERE id = 2"
    )
    legacy.execute(
        "UPDATE orders SET sync_attempts = sync_attempts + 1 WHERE id = 2"
    )
    row = legacy.execute(
        "SELECT sync_status, sync_error, sync_attempts FROM orders WHERE id = 2"
    ).fetchone()
    check(
        row == ("failed", "timeout", 1),
        "v3 sobre v2 · failed guarda error e intentos",
    )

    total = legacy.execute(
        "SELECT COUNT(*) FROM orders WHERE sync_status <> 'synced'"
    ).fetchone()[0]
    check(total == 1, "v3 sobre v2 · la cola heredada tiene 1 pedido")

    # ------------------------------------------------------------------ resumen
    failed = [message for ok, message in results if not ok]
    print()
    print(f"{len(results) - len(failed)}/{len(results)} comprobaciones OK")
    if failed:
        print("Fallaron:")
        for message in failed:
            print(" -", message)
        return 1
    print("Esquema v3 verificado con SQLite", sqlite3.sqlite_version)
    return 0


if __name__ == "__main__":
    sys.exit(main())
