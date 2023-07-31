-- 1) Создать хранимую процедуру, которая, не уничтожая базу данных,
-- уничтожает все те таблицы текущей базы данных, имена которых начинаются с фразы 'TableName'.

CREATE TABLE TableNameFirstNames
(
    name VARCHAR    
);
CREATE TABLE TableNameSecondNames
(
    name VARCHAR
);
CREATE TABLE TableNameThirdNames
(
    name VARCHAR
);

CREATE OR REPLACE PROCEDURE drop_table_if_name_starts_with()
AS
$$
DECLARE
    table_name TEXT;
BEGIN
    FOR table_name IN (SELECT tablename
                       FROM pg_tables
                       WHERE schemaname = 'public'
                         AND tablename ILIKE 'TableName%')
        LOOP
            EXECUTE 'DROP TABLE IF EXISTS ' || table_name || ' CASCADE';
        END LOOP;
END;
$$
    LANGUAGE plpgsql;

CALL drop_table_if_name_starts_with();

-- 2) Создать хранимую процедуру с выходным параметром, которая выводит список
-- имен и параметров всех скалярных SQL функций пользователя в текущей базе данных.
-- Имена функций без параметров не выводить.
-- Имена и список параметров должны выводиться в одну строку.
-- Выходной параметр возвращает количество найденных функций.

CREATE OR REPLACE PROCEDURE count_table(OUT count int) AS
$$
BEGIN
    WITH funName AS (SELECT routine_name, data_type, specific_name
                     FROM information_schema.routines
                     WHERE routine_type = 'FUNCTION'),
         funParam AS (SELECT specific_schema, parameter_mode, parameter_name, specific_name
                      FROM information_schema.parameters
                      WHERE parameter_name IS NOT NULL),
         NameAndParam AS (SELECT routine_name                                                              AS function,
                                 '(' || parameter_mode || ',' || parameter_name || ',' || data_type || ')' AS parameter
                          FROM funName AS name
                                   FULL JOIN funParam AS parameters ON parameters.specific_name = name.specific_name
                          WHERE routine_name IS NOT NULL
                            AND specific_schema = 'public'),
         unification AS (SELECT function || ' ' || string_agg(parameter, ',')
                         FROM NameAndParam
                         GROUP BY function)

    SELECT COUNT(*)
    INTO count
    FROM unification;
END;
$$
    LANGUAGE plpgsql;

CALL count_table(NULL);
-- 3) Создать хранимую процедуру с выходным параметром,
-- которая уничтожает все SQL DML триггеры в текущей базе данных.
-- Выходной параметр возвращает количество уничтоженных триггеров.

---------------------test triggers----------------------
CREATE OR REPLACE FUNCTION insert_lower_nickname() RETURNS TRIGGER AS
$trg_insert_lower_nickname$
BEGIN
    new.nickname := lower(new.nickname);
    RETURN new;
END;
$trg_insert_lower_nickname$
    LANGUAGE plpgsql;

CREATE TRIGGER trg_insert_lower_nickname
    BEFORE UPDATE OR INSERT
    ON Peers
    FOR EACH ROW
EXECUTE PROCEDURE insert_lower_nickname();


CREATE TRIGGER trg_insert_lower_nickname2
    BEFORE UPDATE OR INSERT
    ON Peers
    FOR EACH ROW
EXECUTE PROCEDURE insert_lower_nickname();

---------------------function----------------------
CREATE OR REPLACE FUNCTION delete_all_triggers() RETURNS INTEGER AS
$$
DECLARE
    trg_name TEXT;
    table_name
             TEXT;
    num_triggers
             INT := 0;
BEGIN
    FOR trg_name, table_name IN (
        SELECT tgname, relname
        FROM pg_trigger
                 JOIN pg_class ON pg_trigger.tgrelid = pg_class.oid
        WHERE tgrelid IN (SELECT oid FROM pg_class WHERE relkind = 'r')
          AND tgconstraint = 0)
        LOOP
            EXECUTE 'DROP TRIGGER ' || trg_name || ' ON ' || table_name;
            num_triggers
                := num_triggers + 1;
        END LOOP;
    RETURN num_triggers;
END;
$$
    LANGUAGE plpgsql;

select delete_all_triggers() AS count;

-- 4) Создать хранимую процедуру с входным параметром,
-- которая выводит имена и описания типа объектов (только хранимых процедур и скалярных функций),
-- в тексте которых на языке SQL встречается строка, задаваемая параметром процедуры.

CREATE OR REPLACE PROCEDURE search_objects(IN name TEXT, IN ref refcursor) AS
$$
BEGIN
    OPEN ref FOR
        SELECT p.proname                                    AS object_name,
               pg_catalog.obj_description(p.oid, 'pg_proc') AS object_description
        FROM pg_catalog.pg_proc p
        WHERE p.proname ILIKE '%' || name || '%'
        UNION
        SELECT p.proname                                    AS object_name,
               pg_catalog.obj_description(p.oid, 'pg_proc') AS object_description
        FROM pg_catalog.pg_proc p
        WHERE p.prokind = 'f'
          AND p.proname ILIKE '%' || name || '%';
END;
$$
    LANGUAGE plpgsql;

BEGIN;
CALL search_objects('date', 'ref');
FETCH ALL IN "ref";
END;


