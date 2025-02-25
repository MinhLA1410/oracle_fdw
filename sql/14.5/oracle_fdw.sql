/*
 * Install the extension and define the tables.
 * All the foreign tables defined refer to the same Oracle table.
 */

--Testcase 1:
SET client_min_messages = WARNING;

--Testcase 2:
CREATE EXTENSION oracle_fdw;

-- TWO_TASK or ORACLE_HOME and ORACLE_SID must be set in the server's environment for this to work
--Testcase 3:
CREATE SERVER oracle FOREIGN DATA WRAPPER oracle_fdw OPTIONS (dbserver '', isolation_level 'read_committed', nchar 'true');

--Testcase 4:
CREATE USER MAPPING FOR CURRENT_USER SERVER oracle OPTIONS (user 'SCOTT', password 'tiger');

-- drop the Oracle tables if they exist
DO
$$BEGIN
--Testcase 5:
   SELECT oracle_execute('oracle', 'DROP TABLE scott.typetest1 PURGE');
EXCEPTION
   WHEN OTHERS THEN
      NULL;
END;$$;

DO
$$BEGIN
--Testcase 6:
   SELECT oracle_execute('oracle', 'DROP TABLE scott.gis PURGE');
EXCEPTION
   WHEN OTHERS THEN
      NULL;
END;$$;

--Testcase 7:
SELECT oracle_execute(
          'oracle',
          E'CREATE TABLE scott.typetest1 (\n'
          '   id  NUMBER(5)\n'
          '      CONSTRAINT typetest1_pkey PRIMARY KEY,\n'
          '   c   CHAR(10 CHAR),\n'
          '   nc  NCHAR(10),\n'
          '   vc  VARCHAR2(10 CHAR),\n'
          '   nvc NVARCHAR2(10),\n'
          '   lc  CLOB,\n'
          '   r   RAW(10),\n'
          '   u   RAW(16),\n'
          '   lb  BLOB,\n'
          '   lr  LONG RAW,\n'
          '   b   NUMBER(1),\n'
          '   num NUMBER(7,5),\n'
          '   fl  BINARY_FLOAT,\n'
          '   db  BINARY_DOUBLE,\n'
          '   d   DATE,\n'
          '   ts  TIMESTAMP WITH TIME ZONE,\n'
          '   ids INTERVAL DAY TO SECOND,\n'
          '   iym INTERVAL YEAR TO MONTH\n'
          ') SEGMENT CREATION IMMEDIATE'
       );

--Testcase 8:
SELECT oracle_execute(
          'oracle',
          E'CREATE TABLE scott.gis (\n'
          '   id  NUMBER(5) PRIMARY KEY,\n'
          '   g   MDSYS.SDO_GEOMETRY\n'
          ') SEGMENT CREATION IMMEDIATE'
       );

-- gather statistics
--Testcase 9:
SELECT oracle_execute(
          'oracle',
          E'BEGIN\n'
          '   DBMS_STATS.GATHER_TABLE_STATS (''SCOTT'', ''TYPETEST1'', NULL, 100);\n'
          'END;'
       );

--Testcase 10:
SELECT oracle_execute(
          'oracle',
          E'BEGIN\n'
          '   DBMS_STATS.GATHER_TABLE_STATS (''SCOTT'', ''GIS'', NULL, 100);\n'
          'END;'
       );

-- create the foreign tables
--Testcase 11:
CREATE FOREIGN TABLE typetest1 (
   id  integer OPTIONS (key 'yes') NOT NULL,
   q   double precision,
   c   character(10),
   nc  character(10),
   vc  character varying(10),
   nvc character varying(10),
   lc  text,
   r   bytea,
   u   uuid,
   lb  bytea,
   lr  bytea,
   b   boolean,
   num numeric(7,5),
   fl  float,
   db  double precision,
   d   date,
   ts  timestamp with time zone,
   ids interval,
   iym interval
) SERVER oracle OPTIONS (table 'TYPETEST1');
--Testcase 12:
ALTER FOREIGN TABLE typetest1 DROP q;

-- a table that is missing some fields
--Testcase 13:
CREATE FOREIGN TABLE shorty (
   id  integer OPTIONS (key 'yes') NOT NULL,
   c   character(10)
) SERVER oracle OPTIONS (table 'TYPETEST1');

-- a table that has some extra fields
--Testcase 14:
CREATE FOREIGN TABLE longy (
   id  integer OPTIONS (key 'yes') NOT NULL,
   c   character(10),
   nc  character(10),
   vc  character varying(10),
   nvc character varying(10),
   lc  text,
   r   bytea,
   u   uuid,
   lb  bytea,
   lr  bytea,
   b   boolean,
   num numeric(7,5),
   fl  float,
   db  double precision,
   d   date,
   ts  timestamp with time zone,
   ids interval,
   iym interval,
   x   integer
) SERVER oracle OPTIONS (table 'TYPETEST1');

/*
 * Empty the table and INSERT some samples.
 */

-- will fail with a read-only transaction
--Testcase 15:
ALTER SERVER oracle OPTIONS (SET isolation_level 'read_only');
--Testcase 16:
SELECT oracle_close_connections();
--Testcase 17:
DELETE FROM typetest1;

-- use the default SERIALIZABLE isolation level from now on
--Testcase 18:
ALTER SERVER oracle OPTIONS (DROP isolation_level);
--Testcase 19:
SELECT oracle_close_connections();
--Testcase 20:
DELETE FROM typetest1;

--Testcase 21:
INSERT INTO typetest1 (id, c, nc, vc, nvc, lc, r, u, lb, lr, b, num, fl, db, d, ts, ids, iym) VALUES (
   1,
   'fixed char',
   'nat''l char',
   'varlena',
   'nat''l var',
   'character large object',
   bytea('\xDEADBEEF'),
   uuid('055e26fa-f1d8-771f-e053-1645990add93'),
   bytea('\xDEADBEEF'),
   bytea('\xDEADBEEF'),
   TRUE,
   3.14159,
   3.14159,
   3.14159,
   '1968-10-20',
   '2009-01-26 15:02:54.893532 PST',
   '1 day 2 hours 30 seconds 1 microsecond',
   '-6 months'
);

-- change the "boolean" in Oracle to "2"
--Testcase 22:
SELECT oracle_execute('oracle', 'UPDATE typetest1 SET b = 2 WHERE id = 1');

--Testcase 23:
INSERT INTO shorty (id, c) VALUES (2, NULL);

--Testcase 24:
INSERT INTO typetest1 (id, c, nc, vc, nvc, lc, r, u, lb, lr, b, num, fl, db, d, ts, ids, iym) VALUES (
   3,
   E'a\u001B\u0007\u000D\u007Fb',
   E'a\u001B\u0007\u000D\u007Fb',
   E'a\u001B\u0007\u000D\u007Fb',
   E'a\u001B\u0007\u000D\u007Fb',
   E'a\u001B\u0007\u000D\u007Fb ABC' || repeat('X', 9000),
   bytea('\xDEADF00D'),
   uuid('055f3b32-a02c-4532-e053-1645990a6db2'),
   bytea('\xDEADF00DDEADF00DDEADF00D'),
   bytea('\xDEADF00DDEADF00DDEADF00D'),
   FALSE,
   -2.71828,
   -2.71828,
   -2.71828,
   '0044-03-15 BC',
   '0044-03-15 12:00:00 BC',
   '-2 days -12 hours -30 minutes',
   '-2 years -6 months'
);

--Testcase 25:
INSERT INTO typetest1 (id, c, nc, vc, nvc, lc, r, u, lb, lr, b, num, fl, db, d, ts, ids, iym) VALUES (
   4,
   'short',
   'short',
   'short',
   'short',
   'short',
   bytea('\xDEADF00D'),
   uuid('0560ee34-2ef9-1137-e053-1645990ac874'),
   bytea('\xDEADF00D'),
   bytea('\xDEADF00D'),
   NULL,
   0,
   0,
   0,
   NULL,
   NULL,
   '23:59:59.999999',
   '3 years'
);

/*
 * Test SELECT, UPDATE ... RETURNING, DELETE and transactions.
 */

-- simple SELECT
--Testcase 26:
SELECT id, c, nc, vc, nvc, length(lc), r, u, length(lb), length(lr), b, num, fl, db, d, ts, ids, iym, x FROM longy ORDER BY id;
-- mass UPDATE
--Testcase 27:
WITH upd (id, c, lb, d, ts) AS
   (UPDATE longy SET c = substr(c, 1, 9) || 'u',
                    lb = lb || bytea('\x00'),
                    lr = lr || bytea('\x00'),
                     d = d + 1,
                    ts = ts + '1 day'
   WHERE id < 3 RETURNING id + 1, c, lb, d, ts)
SELECT * FROM upd ORDER BY id;
-- transactions
BEGIN;
--Testcase 28:
DELETE FROM shorty WHERE id = 2;
SAVEPOINT one;
-- will cause an error
--Testcase 29:
INSERT INTO shorty (id, c) VALUES (1, 'c');
ROLLBACK TO one;
--Testcase 30:
INSERT INTO shorty (id, c) VALUES (2, 'c');
ROLLBACK TO one;
COMMIT;
-- see if the correct data are in the table
--Testcase 31:
SELECT id, c FROM typetest1 ORDER BY id;
-- try to update the nonexistant column (should cause an error)
--Testcase 32:
UPDATE longy SET x = NULL WHERE id = 1;
-- check that UPDATES work with "date" in Oracle and "timestamp" in PostgreSQL
BEGIN;
--Testcase 33:
ALTER FOREIGN TABLE typetest1 ALTER COLUMN d TYPE timestamp(0) without time zone;
--Testcase 34:
UPDATE typetest1 SET d = '1968-10-10 12:00:00' WHERE id = 1 RETURNING d;
ROLLBACK;
-- test if "IN" or "= ANY" expressions are pushed down correctly
--Testcase 35:
SELECT id FROM typetest1 WHERE vc = ANY (ARRAY['short', (SELECT 'varlena'::varchar)]) ORDER BY id;
--Testcase 36:
EXPLAIN (COSTS off) SELECT id FROM typetest1 WHERE vc = ANY (ARRAY['short', (SELECT 'varlena'::varchar)]) ORDER BY id;
-- test modifications that need no foreign scan scan (bug #295)
--Testcase 37:
DELETE FROM typetest1 WHERE FALSE;
--Testcase 38:
UPDATE shorty SET c = NULL WHERE FALSE RETURNING *;
-- test deparsing of ScalarArrayOpExpr where the RHS has different element type than the LHS
--Testcase 39:
SELECT id FROM typetest1 WHERE vc = ANY ('{zzzzz}'::name[]);

/*
 * Test "strip_zeros" column option.
 */

--Testcase 40:
SELECT oracle_execute(
          'oracle',
          'INSERT INTO typetest1 (id, vc) VALUES (5, ''has'' || chr(0) || ''zeros'')'
       );

--Testcase 41:
SELECT vc FROM typetest1 WHERE id = 5;  -- should fail
--Testcase 42:
ALTER FOREIGN TABLE typetest1 ALTER vc OPTIONS (ADD strip_zeros 'yes');
--Testcase 43:
SELECT vc FROM typetest1 WHERE id = 5;  -- should work
--Testcase 44:
ALTER FOREIGN TABLE typetest1 ALTER vc OPTIONS (DROP strip_zeros);

--Testcase 45:
DELETE FROM typetest1 WHERE id = 5;

/*
 * Test EXPLAIN support.
 */

--Testcase 46:
EXPLAIN (COSTS off) UPDATE typetest1 SET lc = current_timestamp WHERE id < 4 RETURNING id + 1;
--Testcase 47:
EXPLAIN (VERBOSE on, COSTS off) SELECT * FROM shorty;
-- this should fetch all columns from the foreign table
--Testcase 48:
EXPLAIN (COSTS off) SELECT typetest1 FROM typetest1;

/*
 * Test parameters.
 */

--Testcase 49:
PREPARE stmt(integer, date, timestamp) AS SELECT d FROM typetest1 WHERE id = $1 AND d < $2 AND ts < $3;
-- six executions to switch to generic plan
--Testcase 50:
EXECUTE stmt(1, '2011-03-09', '2011-03-09 05:00:00');
--Testcase 51:
EXECUTE stmt(1, '2011-03-09', '2011-03-09 05:00:00');
--Testcase 52:
EXECUTE stmt(1, '2011-03-09', '2011-03-09 05:00:00');
--Testcase 53:
EXECUTE stmt(1, '2011-03-09', '2011-03-09 05:00:00');
--Testcase 54:
EXECUTE stmt(1, '2011-03-09', '2011-03-09 05:00:00');
--Testcase 55:
EXPLAIN (COSTS off) EXECUTE stmt(1, '2011-03-09', '2011-03-09 05:00:00');
--Testcase 56:
EXECUTE stmt(1, '2011-03-09', '2011-03-09 05:00:00');
DEALLOCATE stmt;
-- test NULL parameters
--Testcase 57:
SELECT id FROM typetest1 WHERE vc = (SELECT NULL::text);

/*
 * Test current_timestamp.
 */
--Testcase 58:
SELECT id FROM typetest1
   WHERE d < current_date
     AND ts < now()
     AND ts < current_timestamp
     AND ts < 'now'::timestamp
ORDER BY id;

/*
 * Test foreign table based on SELECT statement.
 */

--Testcase 59:
CREATE FOREIGN TABLE qtest (
   id  integer OPTIONS (key 'yes') NOT NULL,
   vc  character varying(10),
   num numeric(7,5)
) SERVER oracle OPTIONS (table '(SELECT id, vc, num FROM typetest1)');

-- INSERT works with simple "view"
--Testcase 60:
INSERT INTO qtest (id, vc, num) VALUES (5, 'via query', -12.5);

--Testcase 61:
ALTER FOREIGN TABLE qtest OPTIONS (SET table '(SELECT id, SUBSTR(vc, 1, 3), num FROM typetest1)');

-- SELECT and DELETE should also work with derived columns
--Testcase 62:
SELECT * FROM qtest ORDER BY id;
--Testcase 63:
DELETE FROM qtest WHERE id = 5;

/*
 * Test COPY
 */

BEGIN;
COPY typetest1 FROM STDIN;
666	cöpy	variation	dynamo	ünicode	Not very long	DEADF00D	9a0cf1eb-02e2-4b1f-bbe0-449fa4a99969	\\x01020304	\\xFFFF	\N	0.11111	0.43211	0.01010	2100-01-29	2050-04-01 19:30:00	12 hours	0 years
777	fdjkl	r89809rew	^ß[]#~	\N	Das also ist des Pudels Kern.	00	fe288446-05f6-4074-9e9e-6ee41af7b377	\\x00	\\x00	FALSE	10	1002	1003	2019-05-01	2019-05-01 0:00:00	0 seconds	1 year
\.
ROLLBACK;

/*
 * Test foreign table as a partition.
 */

--Testcase 64:
CREATE TABLE party (LIKE typetest1) PARTITION BY RANGE (id);
--Testcase 65:
CREATE TABLE defpart PARTITION OF party DEFAULT;
--Testcase 66:
ALTER TABLE party ATTACH PARTITION typetest1 FOR VALUES FROM (1) TO (MAXVALUE);
BEGIN;
COPY party FROM STDIN;
666	cöpy	variation	dynamo	ünicode	Not very long	DEADF00D	9a0cf1eb-02e2-4b1f-bbe0-449fa4a99969	\\x01020304	\\xFFFF	\N	0.11111	0.43211	0.01010	2100-01-29	2050-04-01 19:30:00	12 hours	0 years
777	fdjkl	r89809rew	^ß[]#~	\N	Das also ist des Pudels Kern.	00	fe288446-05f6-4074-9e9e-6ee41af7b377	\\x00	\\x00	FALSE	10	1002	1003	2019-05-01	2019-05-01 0:00:00	0 seconds	1 year
\.
--Testcase 67:
INSERT INTO party (id, lc, lr, lb)
   VALUES (12, 'very long character', '\x0001020304', '\xFFFEFDFC');
--Testcase 68:
SELECT id, lr, lb, c FROM typetest1 ORDER BY id;
ROLLBACK;

BEGIN;
--Testcase 69:
CREATE TABLE shortpart (
   id integer NOT NULL,
   c  character(10)
) PARTITION BY LIST (id);
--Testcase 70:
ALTER TABLE shortpart ATTACH PARTITION shorty FOR VALUES IN (1, 2, 3, 4, 5, 6, 7, 8, 9);
--Testcase 71:
INSERT INTO shortpart (id, c) VALUES (6, 'returnme') RETURNING *;
ROLLBACK;

/*
 * Test triggers on foreign tables.
 */

-- trigger function
--Testcase 72:
CREATE FUNCTION shorttrig() RETURNS trigger LANGUAGE plpgsql AS
$$BEGIN
   IF TG_OP IN ('UPDATE', 'DELETE') THEN
      RAISE WARNING 'trigger % % OLD row: id = %, c = %', TG_WHEN, TG_OP, OLD.id, OLD.c;
   END IF;
   IF TG_OP IN ('INSERT', 'UPDATE') THEN
      RAISE WARNING 'trigger % % NEW row: id = %, c = %', TG_WHEN, TG_OP, NEW.id, NEW.c;
   END IF;
   RETURN NEW;
END;$$;

-- test BEFORE trigger
--Testcase 73:
CREATE TRIGGER shorttrig BEFORE UPDATE ON shorty FOR EACH ROW EXECUTE PROCEDURE shorttrig();
BEGIN;
--Testcase 74:
UPDATE shorty SET id = id + 1 WHERE id = 4;
ROLLBACK;

-- test AFTER trigger
--Testcase 75:
DROP TRIGGER shorttrig ON shorty;
--Testcase 76:
CREATE TRIGGER shorttrig AFTER UPDATE ON shorty FOR EACH ROW EXECUTE PROCEDURE shorttrig();
BEGIN;
--Testcase 77:
UPDATE shorty SET id = id + 1 WHERE id = 4;
ROLLBACK;

-- test AFTER INSERT trigger with COPY
--Testcase 78:
DROP TRIGGER shorttrig ON shorty;
--Testcase 79:
CREATE TRIGGER shorttrig AFTER INSERT ON shorty FOR EACH ROW EXECUTE PROCEDURE shorttrig();
BEGIN;
COPY shorty FROM STDIN;
42	hammer
753	rom
0	\N
\.
ROLLBACK;

/*
 * Test ORDER BY pushdown.
 */

-- don't push down string data types
--Testcase 80:
EXPLAIN (COSTS off) SELECT id FROM typetest1 ORDER BY id, vc;
-- push down complicated expressions
--Testcase 81:
EXPLAIN (COSTS off) SELECT id FROM typetest1 ORDER BY length(vc), CASE WHEN vc IS NULL THEN 0 ELSE 1 END, ts DESC NULLS FIRST FOR UPDATE;
--Testcase 82:
SELECT id FROM typetest1 ORDER BY length(vc), CASE WHEN vc IS NULL THEN 0 ELSE 1 END, ts DESC NULLS FIRST FOR UPDATE;

/*
 * Test that incorrect type mapping throws an error.
 */

-- create table with bad type matches
--Testcase 83:
CREATE FOREIGN TABLE badtypes (
   id  integer OPTIONS (key 'yes') NOT NULL,
   c   xml,
   nc  xml
) SERVER oracle OPTIONS (table 'TYPETEST1');
-- should fail for column "nc", as "c" is not used
--Testcase 84:
SELECT id, nc FROM badtypes WHERE id = 1;
-- this will fail for inserting a NULL in column "c"
--Testcase 85:
INSERT INTO badtypes (id, nc) VALUES (42, XML '<empty/>');
-- remove foreign table
--Testcase 86:
DROP FOREIGN TABLE badtypes;

/*
 * Test subplans (initplans)
 */

-- testcase for bug #364
SELECT id FROM typetest1
WHERE vc NOT IN (SELECT * FROM (VALUES ('short'), ('other')) AS q)
ORDER BY id;

/*
 * Test type coerced array parameters (bug #452)
 */

--Testcase 87:
PREPARE stmt(varchar[]) AS SELECT id FROM typetest1 WHERE vc = ANY ($1);
--Testcase 88:
EXECUTE stmt('{varlena,nonsense}');
--Testcase 89:
EXECUTE stmt('{varlena,nonsense}');
--Testcase 90:
EXECUTE stmt('{varlena,nonsense}');
--Testcase 91:
EXECUTE stmt('{varlena,nonsense}');
--Testcase 92:
EXECUTE stmt('{varlena,nonsense}');
--Testcase 93:
EXECUTE stmt('{varlena,nonsense}');
DEALLOCATE stmt;


/*
 * Test push-down of the LIMIT clause.
 */

-- the LIMIT clause is pushed down with and without ORDER BY
--Testcase 94:
EXPLAIN (COSTS off) SELECT d FROM typetest1 LIMIT 2;
--Testcase 95:
SELECT d FROM typetest1 LIMIT 2;
--Testcase 96:
EXPLAIN (COSTS off) SELECT d FROM typetest1 ORDER BY d LIMIT 2;
--Testcase 97:
SELECT d FROM typetest1 ORDER BY d LIMIT 2;
-- the LIMIT clause is not pushed down because the ORDER BY is not
--Testcase 98:
EXPLAIN (COSTS off) SELECT d FROM typetest1 ORDER BY lc LIMIT 2;
-- with an OFFSET clause, the offset value is added to the limit
--Testcase 99:
EXPLAIN (COSTS off) SELECT * FROM qtest LIMIT 1 OFFSET 2;
--Testcase 100:
SELECT * FROM qtest LIMIT 1 OFFSET 2;
-- no LIMIT push-down if there is a GROUP BY clause
-- use ORDER BY to ensure the stable result
--Testcase 101:
EXPLAIN (COSTS off) SELECT d, count(*) FROM typetest1 GROUP BY d ORDER BY 1 LIMIT 2;
--Testcase 102:
SELECT d, count(*) FROM typetest1 GROUP BY d ORDER BY 1 LIMIT 2;
-- no LIMIT push-down if there is an aggregate function
--Testcase 103:
EXPLAIN (COSTS off) SELECT 12 - count(*) FROM typetest1 LIMIT 1;
--Testcase 104:
SELECT 12 - count(*) FROM typetest1 LIMIT 1;
-- no LIMIT push-down if there is a local WHERE condition
--Testcase 105:
EXPLAIN (COSTS OFF) SELECT id FROM typetest1 WHERE vc < 'u' LIMIT 1;
--Testcase 106:
SELECT id FROM typetest1 WHERE vc < 'u' LIMIT 1;

/* test ANALYZE */

ANALYZE typetest1;
ANALYZE longy;
-- bug reported by Jan
ANALYZE shorty;

/* test if views and SECURITY DEFINER functions use the correct user mapping */

--Testcase 107:
CREATE ROLE duff LOGIN;
GRANT SELECT ON typetest1 TO PUBLIC;

--Testcase 108:
CREATE VIEW v_typetest1 AS SELECT id FROM typetest1;
GRANT SELECT ON v_typetest1 TO PUBLIC;

--Testcase 109:
CREATE VIEW v_join AS
   SELECT id, a.vc, b.c
   FROM typetest1 AS a
      JOIN typetest1 AS b USING (id);
GRANT SELECT ON v_join TO PUBLIC;

--Testcase 110:
CREATE FUNCTION f_typetest1() RETURNS TABLE (id integer)
   LANGUAGE sql SECURITY DEFINER AS
'SELECT id FROM public.typetest1';

--Testcase 111:
SET SESSION AUTHORIZATION duff;
-- this should fail
--Testcase 112:
SELECT id FROM typetest1 ORDER BY id;
-- these should succeed
--Testcase 113:
SELECT id FROM v_typetest1 ORDER BY id;
--Testcase 114:
SELECT c FROM v_join WHERE vc = 'short';
--Testcase 115:
SELECT id FROM f_typetest1() ORDER BY id;
-- clean up
--Testcase 116:
RESET SESSION AUTHORIZATION;
--Testcase 117:
DROP ROLE duff;
--Testcase 118:
DROP EXTENSION oracle_fdw CASCADE;
