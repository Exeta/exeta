# exeta
Exeta is a framework for processing mutually dependent tasks in a distributed heterogeneous computing environment.

The main area of application is Data Warehousing and ETL / ELT development and processing.
Exeta supports definition and use of code generators and execution of the generated code.
It consists of
* a language that enables to define tasks and their dependencies
* a compiler that translates the definition into an internal representation stored in a repository in PostgreSQL database,
* an engine that runs tasks on servers (nodes) of computing environment, and
* a console that enables to operate tasks.
