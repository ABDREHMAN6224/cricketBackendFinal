import pg from 'pg';

const db = new pg.Pool({
    user: "postgres",
    host: "localhost",
    database: "DBMS Cricket",
    password: "root",
    idleTimeoutMillis: 0,
    connectionTimeoutMillis: 0,
    port: 5432
})
export default db;
