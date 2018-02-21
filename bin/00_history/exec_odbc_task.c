#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sql.h>
#include <sqlext.h>

#define BUF_SIZE 1024

void get_task_script(
	char **content)
{
    char buffer[BUF_SIZE];
    size_t contentSize = 1; // includes NULL
    /* Preallocate space.  We could just allocate one char here, but that wouldn't be efficient. */

    fprintf(stdout, "Message : ODBC Executor : Reading SQL script from repository.\n");

    *content = malloc(sizeof(char) * BUF_SIZE);
    if(*content == NULL)
    {
        fprintf(stdout, "Error : ODBC Executor : Reading SQL script failed when allocating content.\n");
        exit(1);
    }
    (*content)[0] = '\0'; // make null-terminated
    while(fgets(buffer, BUF_SIZE, stdin))
    {
        char *old = *content;
        contentSize += strlen(buffer);
        *content = realloc(*content, contentSize);
        if(*content == NULL)
        {
        	fprintf(stdout, "Error : ODBC Executor : Reading SQL script failed when reallocating content.\n");
            free(old);
            exit(2);
        }
        strcat(*content, buffer);
    }

    if(ferror(stdin))
    {
        free(*content);
        fprintf(stdout, "Error : ODBC Executor : Reading SQL script failed.\n");
        exit(3);
    }

    fprintf(stdout, "Message : ODBC Executor : Reading SQL script succeeded.\n");

}

void extract_error(
    char*       fn,
    SQLHANDLE   handle,
    SQLSMALLINT type)
{
    SQLINTEGER  i = 0;
    SQLINTEGER  native;
    SQLCHAR     state[ 7 ];
    SQLCHAR     text[256];
    SQLSMALLINT len;
    SQLRETURN   ret;

    do {
        ret = SQLGetDiagRec(type, handle, ++i, state, &native, text, sizeof(text), &len);
        if (SQL_SUCCEEDED(ret)) {
            fprintf(stdout, "Error : ODBC Executor : %s:%ld:%ld:%s\n", state, (long int) i, (long int) native, text);
            fprintf(stderr, "%s", text);
        }
    } while( ret == SQL_SUCCESS );
}

int main(int argc, char *argv[])
{
	char		ConnStrIn[256];

    SQLHENV     env;
    SQLHDBC     dbc, dbclog;
    SQLRETURN   ret; /* ODBC API return status */
    SQLWCHAR    outstr[1024];
    SQLSMALLINT outstrlen;
    SQLHSTMT    stmt;

    int         run_id;
    char        *SQL;

    printf("argc = %d\n", argc);

    int i;

    for (i = 1 ; i < argc ; i++) {
    	printf("argv[%d] = %s\n", i, argv[i]);
    }

	if(argc != 5) {
    	fprintf(stdout, "Error : ODBC Executor : exec_odbc_task failed due to wrong number of arguments.\n");
    	exit(1);
    }

    run_id = atoi(argv[1]);

    fprintf(stdout, "Message : ODBC Executor : Connecting to [ DSN=%s ; UID=%s ].\n", argv[2], argv[3]);

    snprintf(ConnStrIn, sizeof ConnStrIn, "DSN=%s;UID=%s;PWD=%s;", argv[2], argv[3], argv[4]);

    /* Allocate an environment handle */
    SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &env);
    SQLSetEnvAttr(env, SQL_ATTR_AUTOCOMMIT, (SQLPOINTER) SQL_AUTOCOMMIT_OFF, 0);
    
    /* ODBC 3 support required */
    SQLSetEnvAttr(env, SQL_ATTR_ODBC_VERSION, (SQLPOINTER) SQL_OV_ODBC3, 0);
    
    /* Allocate a connection handle */
    SQLAllocHandle(SQL_HANDLE_DBC, env, &dbc);
    
    /* Connect to the data source */
    ret = SQLDriverConnect(dbc, NULL, (SQLCHAR*) ConnStrIn, SQL_NTS, (SQLCHAR*) outstr, sizeof(outstr), &outstrlen, SQL_DRIVER_COMPLETE);
    if (! SQL_SUCCEEDED(ret)) {
    	fprintf(stdout, "Error : ODBC Executor : Connection failed.\n");
        extract_error("SQLDriverConnect", dbc, SQL_HANDLE_DBC);
        SQLFreeHandle(SQL_HANDLE_DBC, dbc);
        SQLAllocHandle(SQL_HANDLE_DBC, env, &dbclog);
        ret = SQLDriverConnect(dbclog, NULL, (SQLCHAR*) "DSN=postgres-martin;", SQL_NTS, (SQLCHAR*) outstr, sizeof(outstr), &outstrlen, SQL_DRIVER_COMPLETE);
        if (! SQL_SUCCEEDED(ret)) {
        	fprintf(stdout, "Error : ODBC Executor : Log connection failed.\n");
            extract_error("SQLDriverConnect", dbc, SQL_HANDLE_DBC);
        }
        ret = SQLAllocHandle(SQL_HANDLE_STMT, dbclog, &stmt);
    	ret = SQLExecDirect(stmt, (SQLCHAR *) "update exeta.runs set status_id = (select status_id from exeta.run_statuses where status_name = 'FAILED') where run_id = 1", SQL_NTS);
        if (! SQL_SUCCEEDED(ret)) {
        	fprintf(stdout, "Error : ODBC Executor : Log failed.\n");
            extract_error("SQLDriverConnect", dbc, SQL_HANDLE_DBC);
        }
    	SQLEndTran(SQL_HANDLE_ENV, env, SQL_COMMIT);
        SQLFreeHandle(SQL_HANDLE_DBC, dbclog);
        SQLFreeHandle(SQL_HANDLE_ENV, env);
        exit(1);
    }
    fprintf(stdout, "Message : ODBC Executor : Connection succeeded.\n");

    /* Allocate a statement handle */
    ret = SQLAllocHandle(SQL_HANDLE_STMT, dbc, &stmt);
    if(ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
    	fprintf(stdout, "Error : ODBC Executor : SQL handle allocation failed with code %d.\n", ret);
        SQLFreeHandle(SQL_HANDLE_DBC, dbc);
        SQLFreeHandle(SQL_HANDLE_ENV, env);
        exit(1);
    }

	get_task_script(&SQL);
	fprintf(stdout, "Message : ODBC Executor : SQL script to be executed:\n%s", SQL);
	fprintf(stdout, "Message : ODBC Executor : SQL direct execution started.\n");
	ret = SQLExecDirect(stmt, (SQLCHAR *) SQL, SQL_NTS);
	free(SQL);
	if(ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
		fprintf(stdout, "Error : ODBC Executor : SQL direct execution failed.\n");
		extract_error("SQLExecDirect", stmt, SQL_HANDLE_STMT);
		SQLEndTran(SQL_HANDLE_DBC, dbc, SQL_ROLLBACK);
		// Log FAILED
		ret = SQLExecDirect(stmt, (SQLCHAR *) "UPDATE EXETA_RUNS SET RUN_STATUS = 'FAILED' WHERE RUN_ID = 1", SQL_NTS);
		free(SQL);
		SQLFreeHandle(SQL_HANDLE_STMT, stmt);
	    SQLDisconnect(dbc);
		SQLFreeHandle(SQL_HANDLE_DBC, dbc);
		SQLFreeHandle(SQL_HANDLE_ENV, env);
		exit(1);
    }
	fprintf(stdout, "Message : ODBC Executor : SQL direct execution succeeded with code %d.\n", ret);

	SQLLEN rowcnt;
	ret = SQLRowCount(stmt, &rowcnt);
	if(ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
		fprintf(stdout, "Warning : ODBC Executor : Retrieval of a row count processed by SQL failed.\n");
	} else {
		fprintf(stdout, "Message : ODBC Executor : SQL processed %ld rows.\n", rowcnt);
	}

	// Log SUCCEEDED
	ret = SQLExecDirect(stmt, (SQLCHAR *) "UPDATE EXETA_RUNS SET RUN_STATUS = 'SUCCEEDED' WHERE RUN_ID = 1", SQL_NTS);
	if(ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
		fprintf(stdout, "Error : ODBC Executor : SQL direct execution failed.\n");
		extract_error("SQLExecDirect", stmt, SQL_HANDLE_STMT);
		SQLEndTran(SQL_HANDLE_DBC, dbc, SQL_ROLLBACK);
		free(SQL);
		SQLFreeHandle(SQL_HANDLE_STMT, stmt);
	    SQLDisconnect(dbc);
		SQLFreeHandle(SQL_HANDLE_DBC, dbc);
		SQLFreeHandle(SQL_HANDLE_ENV, env);
		exit(2);
    }

	SQLEndTran(SQL_HANDLE_ENV, env, SQL_ROLLBACK);

	SQLFreeHandle(SQL_HANDLE_STMT, stmt);
    SQLDisconnect(dbc);
    SQLFreeHandle(SQL_HANDLE_DBC, dbc);
    SQLFreeHandle(SQL_HANDLE_ENV, env);
    exit(0);
}
