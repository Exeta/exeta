#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sql.h>
#include <sqlext.h>

#define BUF_SIZE 1024

void get_sql(
	char **content)
{
    char buffer[BUF_SIZE];
    size_t contentSize = 1; // includes NULL
    /* Preallocate space.  We could just allocate one char here, but that wouldn't be efficient. */
    *content = malloc(sizeof(char) * BUF_SIZE);
    if(*content == NULL)
    {
        perror("Failed to allocate content");
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
            perror("Failed to reallocate content");
            free(old);
            exit(2);
        }
        strcat(*content, buffer);
    }

    if(ferror(stdin))
    {
        free(*content);
        perror("Error reading from stdin.");
        exit(3);
    }
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

    fprintf(stderr, "\nThe driver reported the following diagnostics whilst running %s\n\n", fn);

    do {
        ret = SQLGetDiagRec(type, handle, ++i, state, &native, text, sizeof(text), &len);
        if (SQL_SUCCEEDED(ret))
            printf("%s:%ld:%ld:%s\n", state, (long int) i, (long int) native, text);
    } while( ret == SQL_SUCCESS );
}

int main(void)
{
    SQLHENV     env;
    SQLHDBC     dbc;
    SQLRETURN   ret; /* ODBC API return status */
    SQLWCHAR    outstr[1024];
    SQLSMALLINT outstrlen;
    SQLHSTMT    stmt;
     
    /* Allocate an environment handle */
    SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &env);
    
    /* We want ODBC 3 support */
    SQLSetEnvAttr(env, SQL_ATTR_ODBC_VERSION, (void *) SQL_OV_ODBC3, 0);
    
    /* Allocate a connection handle */
    SQLAllocHandle(SQL_HANDLE_DBC, env, &dbc);
    
    /* Connect to the DSN mydsn */
    ret = SQLDriverConnect(dbc, NULL, (SQLCHAR*) "DSN=postgres-martin;", SQL_NTS, (SQLCHAR*) outstr, sizeof(outstr), &outstrlen, SQL_DRIVER_COMPLETE);
    
    if (SQL_SUCCEEDED(ret)) {
        printf("Connected.\n");
        
        /* Allocate a statement handle */
        ret = SQLAllocHandle(SQL_HANDLE_STMT, dbc, &stmt);
        
        if(ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
            printf("Error Allocating Handle:\t%d\n", ret);
        } else {
            char *SQL;
            get_sql(&SQL);
            printf("%s\n", SQL);
            ret = SQLExecDirect(stmt, (SQLCHAR *) SQL, SQL_NTS);
            if(ret == SQL_SUCCESS || ret == SQL_SUCCESS_WITH_INFO) {
                SQLLEN rowcnt;
            	printf("SQLExecDirect succeeded.\nSQL return code:\t%d\n\n", ret);
                ret = SQLRowCount(stmt, &rowcnt);
                printf("Rows processed: %ld\n", rowcnt);
            } else {
                printf("SQLExecDirect failed!\n");
                extract_error("SQLExecDirect", stmt, SQL_HANDLE_STMT);
            }
            SQLFreeHandle(SQL_HANDLE_STMT, stmt);
        }
        /* disconnect from driver */
        SQLDisconnect(dbc);
    } else {
        fprintf(stderr, "Failed to connect!\n");
        extract_error("SQLDriverConnect", dbc, SQL_HANDLE_DBC);
    }
    /* free up allocated handles */
    SQLFreeHandle(SQL_HANDLE_DBC, dbc);
    SQLFreeHandle(SQL_HANDLE_ENV, env);
    return 0;
}
