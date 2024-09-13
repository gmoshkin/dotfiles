main :: () {
    logger := New(Sqlite3_Logger);
    logger.proc = context.logger;
    logger.data = context.logger_data;
    // sqlite3_config(SQLITE_CONFIG_LOG, log_trampoline, logger);

    db: *sqlite3;
    rc := sqlite3_open("test.db", *db);
    assert(rc == SQLITE_OK);
    defer sqlite3_close(db);

    // Simple DQL/DML query
    {
        print("running simple DQL/DML queries\n");
        query := #string SQL
            DROP TABLE IF EXISTS test;
            CREATE TABLE IF NOT EXISTS test (id INT PRIMARY KEY, value TEXT, num DOUBLE, data BLOB);
            DELETE FROM test;
            INSERT INTO test VALUES (1, 'foo', 3.14, '?');
        SQL;
        error: *u8;
        rc := sqlite3_exec(db, query.data, null, null, *error);
        assert(rc == SQLITE_OK, "%", to_string(error));
    }

    Row :: struct {
        id: s64;
        value: string;
        num: float32;
        data: [] u8;
    };

    // DML with parameters
    {
        print("running parameterized DML queries\n");
        stmt: *sqlite3_stmt;
        defer sqlite3_finalize(stmt);

        query := #string SQL
            INSERT INTO test VALUES (?, ?, ?, ?);
        SQL;
        rc = sqlite3_prepare_v2(db, query.data, xx query.count, *stmt, null);
        if rc == SQLITE_ERROR {
            set_last_error_from_sql(db);
            log_last_error(.WITH_STACK_TRACE);
            exit(1);
        }
        assert(rc == SQLITE_OK, "%", rc);

        ok := sqlite3_put_values(stmt, 2, "bar", 13.37, u8.[ 0, 1, 2, 4 ]);
        if !ok {
            log_last_error(.WITH_STACK_TRACE);
            exit(1);
        }

        ok = sqlite3_put_struct(stmt, Row.{ 3, "baz", 420.69, xx "blob?" });
        if !ok {
            log_last_error(.WITH_STACK_TRACE);
            exit(1);
        }

        /*
        rc = sqlite3_bind_int(stmt, 1, 4);
        assert(rc == SQLITE_OK);

        value := "hello from jai";
        rc = sqlite3_bind_text(stmt, 2, value.data, xx value.count, SQLITE_STATIC);
        assert(rc == SQLITE_OK);

        rc = sqlite3_step(stmt);
        assert(rc == SQLITE_DONE, "%", rc);
        */
    }

    // Read from db
    {
        print("running DQL queries\n");

        stmt: *sqlite3_stmt;
        defer sqlite3_finalize(stmt);

        query := #string SQL
            SELECT id, value, num, data FROM test;
        SQL;
        rc = sqlite3_prepare_v2(db, query.data, xx query.count, *stmt, null);
        if rc == SQLITE_ERROR {
            set_last_error_from_sql(db);
            log_last_error(.WITH_STACK_TRACE);
            exit(1);
        }
        assert(rc == SQLITE_OK);

        i := 1;
        while true {
            defer i += 1;

            row: Row;
            result := sqlite3_step_and_get_row(stmt, *row);
            if result == .ERROR {
                log_last_error(.WITH_STACK_TRACE);
                break;
            }

            if result == .NO_ROW break;

            print("row #%: %\n", i, row);

            /*
            rc = sqlite3_step(stmt);
            if rc == SQLITE_DONE break;
            assert(rc == SQLITE_ROW, "%", rc);

            type := sqlite3_column_type(stmt, 0);
            assert(type == SQLITE_INTEGER, "%", type);
            id := sqlite3_column_int(stmt, 0);

            type = sqlite3_column_type(stmt, 1);
            assert(type == SQLITE_TEXT, "%", type);
            value := to_string(sqlite3_column_text(stmt, 1));
            print("row #% (%, %)\n", i, id, value);
            */
        }
    }
}

#import "Basic";
#import "Sqlite3";
#import "Error_Info";
System :: #import "System";
