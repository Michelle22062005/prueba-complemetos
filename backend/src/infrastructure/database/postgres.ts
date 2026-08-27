import {
  Pool,
  PoolClient,
  QueryResult,
  QueryResultRow,
} from "pg";

import { env } from "../../config/env";

const pool = new Pool({
  host: env.database.host,
  port: env.database.port,
  user: env.database.user,
  password: env.database.password,
  database: env.database.name,
});

/**
 * Prueba la conexión con PostgreSQL.
 */
export async function testDatabaseConnection(): Promise<void> {
  const result = await pool.query(
    "SELECT current_user, current_database()"
  );

  console.log(
    "PostgreSQL conectado correctamente"
  );

  console.log(
    "Usuario:",
    result.rows[0].current_user
  );

  console.log(
    "Base de datos:",
    result.rows[0].current_database
  );
}

/**
 * Ejecuta una consulta normal.
 */
export async function query<
  T extends QueryResultRow = QueryResultRow
>(
  text: string,
  values: unknown[] = []
): Promise<QueryResult<T>> {
  return pool.query<T>(
    text,
    values
  );
}

/**
 * Ejecuta una operación dentro de una
 * transacción estableciendo el usuario actual.
 *
 * La función callback puede devolver cualquier tipo:
 *
 * - QueryResult
 * - rows
 * - boolean
 * - objetos
 * - etc.
 */
export async function queryAsUser<T>(
  userId: string,
  callback: (
    client: PoolClient
  ) => Promise<T>
): Promise<T> {
  const client =
    await pool.connect();

  try {
    await client.query(
      "BEGIN"
    );

    await client.query(
      `
      SELECT set_config(
        'app.current_user_id',
        $1,
        true
      )
      `,
      [userId]
    );

    const result =
      await callback(client);

    await client.query(
      "COMMIT"
    );

    return result;
  } catch (error) {
    await client.query(
      "ROLLBACK"
    );

    throw error;
  } finally {
    client.release();
  }
}

export {
  pool,
};