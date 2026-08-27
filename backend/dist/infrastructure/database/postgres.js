"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.pool = void 0;
exports.testDatabaseConnection = testDatabaseConnection;
exports.query = query;
exports.queryAsUser = queryAsUser;
const pg_1 = require("pg");
const env_1 = require("../../config/env");
const pool = new pg_1.Pool({
    host: env_1.env.database.host,
    port: env_1.env.database.port,
    user: env_1.env.database.user,
    password: env_1.env.database.password,
    database: env_1.env.database.name,
});
exports.pool = pool;
/**
 * Prueba la conexión con PostgreSQL.
 */
async function testDatabaseConnection() {
    const result = await pool.query("SELECT current_user, current_database()");
    console.log("PostgreSQL conectado correctamente");
    console.log("Usuario:", result.rows[0].current_user);
    console.log("Base de datos:", result.rows[0].current_database);
}
/**
 * Ejecuta una consulta normal.
 */
async function query(text, values = []) {
    return pool.query(text, values);
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
async function queryAsUser(userId, callback) {
    const client = await pool.connect();
    try {
        await client.query("BEGIN");
        await client.query(`
      SELECT set_config(
        'app.current_user_id',
        $1,
        true
      )
      `, [userId]);
        const result = await callback(client);
        await client.query("COMMIT");
        return result;
    }
    catch (error) {
        await client.query("ROLLBACK");
        throw error;
    }
    finally {
        client.release();
    }
}
