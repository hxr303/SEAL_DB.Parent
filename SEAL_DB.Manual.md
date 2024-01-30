# Manual of Search Edit Archive Library (S.E.A.L.) 

<br> 

**Authors**  
*XiangRu Huang,Xavier Mserez, Clara Baumans*

**Contents**
1. Installation of PostgresSQL & pgAdmin
2. Database Creation
3. Connection via R
4. Querying Examples
5. Editing Examples
6. Use of Shiny APP

<br> 

---

<br> 

## 1. Installation of PostgresSQL & pgAdmin

<br> 

### PostgresSQL (version 16)

<br> 

https://www.postgresql.org/download/

* Set default port *5432*
* Set password for default user *postgre*

<br> 

### pgAdmin (version 4 v8.2)

<br> 

https://www.pgadmin.org/download/

Login the default server with default port, default user with the password you have set. The default server information:  
* Hostname: *localhost*
* Port: *5432*
* Password: *password*
* User: *postgres*

<br> 

---

<br> 

## 2. Database Creation

<br> 

Download the folder called *Project_DB2* that is available in Github (?????). It contains all the queries, functions, and files required to build this database with some contained data. 

<br> 

**1. Open pgAdmin, log in to your server.**

<br> 

**2. Import tables.**

1. Create the foundation of the data structure and that is to implement it in the tables by *Query Tool*. Run the following code (*all_tables.sql*) and The query consists of five incomplete tables. (Delete picture_number constraint in case of ERROR)
   1. Data_tags  	
   2. Data_reference		
   3. Data_uncertainty
   4. User_data (private table)
   5. User_documentation

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- data_reference table is used to allow for files to be exported
CREATE TABLE IF NOT EXISTS public.data_reference
(
    serial_id SERIAL PRIMARY KEY,
    link_path text COLLATE pg_catalog."default",
    picture_number integer,
    stored_image_oid OID
);

-- The main table containing the tags for the images
-- The commented out section will be filled with an ALTER TABLE QUERY
CREATE TABLE IF NOT EXISTS public.data_tags
(
    specimen text COLLATE pg_catalog."default",
    bone text COLLATE pg_catalog."default",
    sex text COLLATE pg_catalog."default",
    age text COLLATE pg_catalog."default",
    side_of_body text COLLATE pg_catalog."default",
    plane_of_picture text COLLATE pg_catalog."default",
    orientation text COLLATE pg_catalog."default",
    picture_number integer,
    logic_tag SERIAL PRIMARY KEY,
    scrape_name text COLLATE pg_catalog."default",
    CONSTRAINT unique_picture_number UNIQUE (picture_number)
);

-- The main table containing the uncertainties of each of the tags (datatype: BOOL)
CREATE TABLE IF NOT EXISTS public.uncertainty
(
    serial_id SERIAL PRIMARY KEY,
    uncertainty_specimen text COLLATE pg_catalog."default",
    uncertainty_bone text COLLATE pg_catalog."default",
    uncertainty_sex text COLLATE pg_catalog."default",
    uncertainty_age text COLLATE pg_catalog."default",
    uncertainty_side_of_body text COLLATE pg_catalog."default",
    uncertainty_plane_of_picture text COLLATE pg_catalog."default",
    uncertainty_orientation text COLLATE pg_catalog."default",
    picture_number integer
);

-- Table that records users, filled by the insert_user_data()
CREATE TABLE IF NOT EXISTS public.user_data
(
    user_id uuid DEFAULT uuid_generate_v4(),
    username1 character varying(255) COLLATE pg_catalog."default",
    logic_id SERIAL PRIMARY KEY,
    user_random integer
);

-- Table documenting users' intentions, filled by perform_user_action_with_documentation()
CREATE TABLE IF NOT EXISTS public.user_documentation
(
    documentation_id SERIAL PRIMARY KEY,
    action_type character varying(255) COLLATE pg_catalog."default",
    affected_row_id integer,
    "timestamp" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    user_random integer
);
```

2. Import *data_tags.csv* into the *data_tags* table, it is important that only the specified columns get imported. Import *link_path.csv* into the *data_reference* table, *link_path* is the only column selected. Import *Uncertainty.csv* into the *uncertainty* table, all columns should be selected except for *serial_id* and *picture_number*.

<br> 
<br>

**3. Create all functions by running the following code in *Query Tool*. Make sure every function is created successfully.**  

<br> 

*export_image.sql*
```sql
-- FUNCTION: public.export_image(integer, text)

-- DROP FUNCTION IF EXISTS public.export_image(integer, text);

CREATE OR REPLACE FUNCTION public.export_image(
	p_picture_number integer,
	p_output_directory text)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    image_oid OID;
    file_path TEXT;
    scrape_name TEXT;
BEGIN
    -- Retrieve the scrape_name from data_tags
    SELECT dt.scrape_name INTO scrape_name
    FROM data_tags dt
    WHERE dt.picture_number = p_picture_number;

    -- Retrieve the image OID from data_reference
    SELECT dr.stored_image_OID INTO image_oid
    FROM data_reference dr
    WHERE dr.picture_number = p_picture_number;

    IF image_oid IS NOT NULL THEN
        -- Generate the file path in the output directory with scrape_name
        file_path := p_output_directory || '/' || scrape_name || '.jpg';

        -- Export the Large Object data to a file using lo_export
        PERFORM lo_export(image_oid, file_path);
    ELSE
        RAISE NOTICE 'No image found for picture_number %', p_picture_number;
    END IF;
END;
$BODY$;

ALTER FUNCTION public.export_image(integer, text)
    OWNER TO postgres;
```

<br>

*import_image.sql*
```sql
-- FUNCTION: public.import_image(text, text[], boolean[])

-- DROP FUNCTION IF EXISTS public.import_image(text, text[], boolean[]);

CREATE OR REPLACE FUNCTION public.import_image(
	p_image_path text,
	p_data_tags text[],
	p_data_uncertainties boolean[])
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    l_unique_name text;
    l_picture_number INTEGER;
    l_file_path text;
    l_oid OID;
    l_directory text := 'C:\Program Files\PostgreSQL\16\data\PermissionData\Export\';
BEGIN
    -- Generate a unique random number
    l_picture_number := generate_unique_random_number();

    -- Generate unique text scrape
    l_unique_name = generate_unique_identifier(p_data_tags) || l_picture_number::text;

    -- Define the file path in the storage directory
    l_file_path := l_directory || l_unique_name;

    -- Use lo_import to get OID for image data
    l_oid := lo_import(p_image_path);

    -- Export the image data to a file in the storage directory
    EXECUTE 'SELECT lo_export($1, $2)' USING l_oid, l_file_path;

    -- Call insert_data_tags with the array of tags and the generated picture_number
    PERFORM insert_data_tags(p_data_tags, l_picture_number, l_unique_name);

    -- Call insert_uncertainty with the array of boolean values corresponding to the data_tags
    PERFORM insert_data_uncertainty(p_data_uncertainties, l_picture_number);

    -- Insert the file path and OID into the data_reference table
    PERFORM insert_data_reference(l_picture_number, l_file_path, l_oid);
END;
$BODY$;

ALTER FUNCTION public.import_image(text, text[], boolean[])
    OWNER TO postgres;
```

<br>

*insert_data_reference.sql*
```sql
-- FUNCTION: public.insert_data_reference(integer, text, OID)

-- DROP FUNCTION IF EXISTS public.insert_data_reference(integer, text, OID);

CREATE OR REPLACE FUNCTION public.insert_data_reference(
	p_picture_number integer,
	p_link_path text,
	p_stored_image_oid OID)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN
    INSERT INTO public.data_reference (picture_number, link_path, stored_image_OID)
    VALUES (p_picture_number, p_link_path, p_stored_image_OID);
END;
$BODY$;

ALTER FUNCTION public.insert_data_reference(integer, text, OID)
    OWNER TO postgres;
```

<br>

*insert_data_tags.sql*
```sql
CREATE OR REPLACE FUNCTION public.insert_data_tags(
    p_data_tags text[],
    p_picture_number integer,
    p_scrape_names text
)
RETURNS void
LANGUAGE 'plpgsql'
COST 100
VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN
    -- Check array length before accessing specific indices
    IF array_length(p_data_tags, 1) >= 7 THEN
        -- Insert into data_tags table
        INSERT INTO data_tags (
            picture_number,
            specimen,
            bone,
            sex,
            age,
            side_of_body,
            plane_of_picture,
            orientation,
            scrape_name
        )
        VALUES (
            p_picture_number,
            p_data_tags[1],
            p_data_tags[2],
            p_data_tags[3],
            p_data_tags[4],
            p_data_tags[5],
            p_data_tags[6],
            p_data_tags[7],
            p_scrape_names
        );
    ELSE
        -- Handle the case where the array doesn't have enough elements
        RAISE EXCEPTION 'Array p_data_tags does not have enough elements.';
    END IF;
END;
$BODY$;

ALTER FUNCTION public.insert_data_tags(text[], integer, text)
OWNER TO postgres;
```

<br>


*insert_data_uncertainty.sql*
```sql
-- FUNCTION: public.insert_data_uncertainty(integer, text[])

-- DROP FUNCTION IF EXISTS public.insert_data_uncertainty(integer, text[]);

CREATE OR REPLACE FUNCTION public.insert_data_uncertainty(
	p_data_uncertainty BOOLEAN[],
	picture_number1 INTEGER
	)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN
    -- Insert a new row into uncertainty with the provided uncertainties and picture_number
    INSERT INTO uncertainty (
        picture_number,
        uncertainty_specimen,
        uncertainty_bone,
        uncertainty_sex,
        uncertainty_age,
        uncertainty_side_of_body,
        uncertainty_plane_of_picture,
        uncertainty_orientation
    )
    VALUES (
        picture_number1,
        p_data_uncertainty[1],
        p_data_uncertainty[2],
        p_data_uncertainty[3],
        p_data_uncertainty[4],
        p_data_uncertainty[5],
        p_data_uncertainty[6],
        p_data_uncertainty[7]
    );
END;
$BODY$;

ALTER FUNCTION public.insert_data_uncertainty(boolean[], integer)
    OWNER TO postgres;
```

<br>

*insert_user_data.sql*
```sql
CREATE OR REPLACE FUNCTION public.insert_user_data(
	p_username1 character varying)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN
    INSERT INTO user_data (user_id, username1, user_random)
    VALUES (uuid_generate_v4(), p_username1, generate_random_number_5_digits());
END;
$BODY$;

ALTER FUNCTION public.insert_user_data(character varying)
    OWNER TO postgres;
```

<br>

*generate_unique_identifier.sql*
```sql
CREATE OR REPLACE FUNCTION public.generate_unique_identifier(
	data_list text[])
    RETURNS character varying
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_identifier VARCHAR(255);
BEGIN
    -- Concatenate non-null tags into one long string
    SELECT CONCAT_WS('',
        COALESCE(data_list[1], ''),  -- assuming data_list[1] corresponds to specimen
        COALESCE(data_list[2], ''),  -- assuming data_list[2] corresponds to bone
        COALESCE(data_list[3], ''),  -- assuming data_list[3] corresponds to sex
        COALESCE(data_list[4], ''),  -- assuming data_list[4] corresponds to age
        COALESCE(data_list[5], ''),  -- assuming data_list[5] corresponds to side_of_body
        COALESCE(data_list[6], ''),  -- assuming data_list[6] corresponds to plane_of_picture
        COALESCE(data_list[7], '')   -- assuming data_list[7] corresponds to orientation
    )
    INTO v_identifier;

    RETURN v_identifier;
END;
$BODY$;

ALTER FUNCTION public.generate_unique_identifier(text[])
    OWNER TO postgres;
```

<br>

*generate_unique_random_number_5.sql*
```sql
CREATE OR REPLACE FUNCTION public.generate_random_number_5_digits(
	)
    RETURNS integer
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    random_number INTEGER;
BEGIN
    -- Generate a random 5-digit number
    WHILE TRUE
    LOOP
        random_number := floor(random() * (99999 - 10000 + 1) + 10000)::INTEGER;

        EXIT WHEN NOT EXISTS (SELECT 1 FROM your_table WHERE your_column = random_number);
    END LOOP;

    RETURN random_number;
END;
$BODY$;

ALTER FUNCTION public.generate_random_number_5_digits()
    OWNER TO postgres;
```

<br>

*generate_unique_random_number_6.sql*
```sql
CREATE OR REPLACE FUNCTION public.generate_unique_random_number(
	)
    RETURNS integer
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    random_number INTEGER;
BEGIN
    LOOP
        random_number := floor(random() * 900000 + 100000)::INTEGER;
        EXIT WHEN NOT EXISTS (SELECT 1 FROM data_tags WHERE picture_number = random_number);
    END LOOP;

    RETURN random_number;
END;
$BODY$;

ALTER FUNCTION public.generate_unique_random_number()
    OWNER TO postgres;
```

<br>


*admin_create.sql*
```sql
CREATE OR REPLACE FUNCTION public.admin_create(
	user_name character varying,
	user_password character varying)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
	BEGIN
		EXECUTE 'CREATE ROLE ' || quote_ident(user_name) || ' PASSWORD ' || quote_literal(user_password) || ' SUPERUSER';
    	EXECUTE 'ALTER ROLE ' || quote_ident(user_name) || ' CREATEROLE';
		SELECT insert_user_data(user_name);
	END;
$BODY$;
```

<br>

*create_standard_user.sql*
```sql
CREATE OR REPLACE FUNCTION public.create_standard_user(
	p_username character varying,
	p_password character varying)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN
    -- Create the user
    EXECUTE 'CREATE USER ' || quote_ident(p_username) || ' WITH PASSWORD ' || quote_literal(p_password);

    -- Grant privileges to add, change, and delete rows
    EXECUTE 'GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ' || quote_ident(p_username);

    -- Grant privileges to import/export OID files
    EXECUTE 'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ' || quote_ident(p_username);

    -- Grant privileges to import/export text arrays
    EXECUTE 'GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO ' || quote_ident(p_username);
	SELECT insert_user_data(p_username);
END;
$BODY$;

ALTER FUNCTION public.create_standard_user(character varying, character varying)
    OWNER TO postgres;
```

<br>

*perform_user_action_with_documentation.sql*
```sql
CREATE OR REPLACE FUNCTION public.perform_user_action_with_documentation(
	p_username character varying,
	p_action_type character varying,
	p_affected_picture_number integer)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_user_id INTEGER;
BEGIN
    -- Retrieve the user_id based on the provided username
    SELECT user_random INTO v_user_id
    FROM user_data
    WHERE username1 = p_username;

    IF NOT FOUND THEN
        -- Username does not exist, handle accordingly
        RAISE EXCEPTION 'Username % does not exist in user_data', p_username;
    END IF;

    -- Record the action in user_documentation using the retrieved user_id and affected_picture_number
    INSERT INTO user_documentation (user_random, action_type, affected_row_id, timestamp)
    VALUES (v_user_id, p_action_type, p_affected_picture_number, CURRENT_TIMESTAMP);
END;
$BODY$;

ALTER FUNCTION public.perform_user_action_with_documentation(character varying, character varying, integer)
    OWNER TO postgres;
```

<br>

*picture_number_column_generator.sql*
```sql
DO $$ 
DECLARE
    row_data RECORD;
    new_picture_number INTEGER;
BEGIN
    -- Loop through rows where specimen is not NULL
    FOR row_data IN SELECT * FROM public.data_tags WHERE specimen IS NOT NULL
    LOOP
        -- Generate a new unique random number
        new_picture_number := generate_unique_random_number();

        -- Update each row with the generated random number
        UPDATE public.data_tags
        SET picture_number = new_picture_number
        WHERE logic_tag = row_data.logic_tag;

        -- You can add additional logic or print statements if needed
        -- RAISE NOTICE 'Updated picture_number for logic_tag %', row_data.logic_tag;
    END LOOP;
END $$;
```

<br>

*picture_number_from_data_tags_to_data_reference.sql*
```sql
UPDATE data_reference
SET picture_number = data_tags.picture_number
FROM data_tags
WHERE data_reference.serial_id = data_tags.logic_tag;
```

*picture_number_from_data_tags_to_uncertainty.sql*
```sql
UPDATE uncertainty
SET picture_number = data_tags.picture_number
FROM data_tags
WHERE uncertainty.serial_id = data_tags.logic_tag;
```

<br>

*remove_rows.sql*
```sql
-- Assuming you want to delete rows from data_tags where logic_tag is in [125, 126, 127]
DELETE FROM data_tags
WHERE logic_tag IN (125, 126, 127);

-- Assuming you want to delete rows from data_tags where logic_tag is in [125, 126, 127]
DELETE FROM data_reference
WHERE serial_id IN (125, 126, 127);

-- Assuming you want to delete rows from data_tags where logic_tag is in [125, 126, 127]
DELETE FROM uncertainty
WHERE serial_id IN (125, 126, 127);
```

<br>

*insert_data_reference_oid.sql*
```sql
DO $$ 
DECLARE
    row_data RECORD;                                 -- declaring row_data for the FOR loop
    image_oid OID;                                   -- Large object declaration (this will store the image data)
BEGIN
    FOR row_data IN (SELECT link_path FROM data_reference) LOOP
        BEGIN
            -- Import the image into the Large Object
            BEGIN
                image_oid := lo_import(row_data.link_path);
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE NOTICE 'Error importing image for path: %, Error: %', row_data.link_path, SQLERRM;
                    CONTINUE; -- Skip to the next iteration in case of an error
            END;

            -- Update the existing row with the new stored_image_oid
            UPDATE data_reference 
            SET stored_image_oid = image_oid
            WHERE link_path = row_data.link_path;

            RAISE NOTICE 'Image imported and stored successfully for path: %', row_data.link_path;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Error processing file: %, Error: %', row_data.link_path, SQLERRM;
        END;
    END LOOP;
END $$;
```

<br>

*insert_scrape_names.sql*
```sql
DO $$ 
DECLARE
    v_scrape_name TEXT;
    data_row public.data_tags;
BEGIN
    -- Loop through each row in the table
    FOR data_row IN (SELECT * FROM public.data_tags WHERE specimen IS NOT NULL) LOOP
        -- Concatenate the values for the current row
        v_scrape_name := COALESCE(data_row.specimen, '') || 
                         COALESCE(data_row.bone, '') || 
                         COALESCE(data_row.sex, '') || 
                         COALESCE(data_row.age, '') || 
                         COALESCE(data_row.side_of_body, '') || 
                         COALESCE(data_row.plane_of_picture, '') || 
                         COALESCE(data_row.orientation, '') || 
                         COALESCE(CAST(data_row.picture_number AS TEXT), ''); -- Cast picture_number to TEXT
        
        -- Update the scrape_name column for the current row
        UPDATE public.data_tags
        SET scrape_name = v_scrape_name
        WHERE logic_tag = data_row.logic_tag;
        
        RAISE NOTICE 'Specimen: %, Scrape Name: %', data_row.specimen, v_scrape_name;
    END LOOP;
END $$;
```

<br>
<br>

**Note: run the following code *only* when import doesn’t work properly.**

*data_tags_adjustment.sql*
```sql
-- Create the sequence
CREATE SEQUENCE data_tags_logic_tag_seq;

-- Add the columns to data_tags
ALTER TABLE public.data_tags
ADD COLUMN picture_number INTEGER,
ADD COLUMN logic_tag INTEGER NOT NULL DEFAULT nextval('data_tags_logic_tag_seq'::regclass),
ADD COLUMN scrape_name TEXT COLLATE pg_catalog."default",
ADD CONSTRAINT data_tags_pkey PRIMARY KEY (logic_tag),
ADD CONSTRAINT unique_picture_number UNIQUE (picture_number);
```

*data_reference_adjustment*
```sql
-- Add a picture_number column to the data_reference table
ALTER TABLE public.data_reference
ADD COLUMN picture_number integer;

-- Delete rows with null
DELETE FROM public.data_reference
WHERE picture_number IS NULL;

-- Add a primary key constraint using picture_number
ALTER TABLE public.data_reference
ADD CONSTRAINT data_reference_pkey PRIMARY KEY (picture_number);

-- Add a foreign key constraint referencing the picture_number column in data_tags
ALTER TABLE public.data_reference
ADD CONSTRAINT data_reference_data_tags_fk
FOREIGN KEY (picture_number)
REFERENCES public.data_tags (picture_number);
```


<br> 
<br> 


---

<br> 

## 3. Connection via R

<br> 

**Software setup needed, install and library package *RPostgreSQL* in R.**
```r
install.packages("RPostgreSQL")
library(RPostgreSQL)
```

<br> 

**Establish the connection, by providing name of database, port of server, user name and password.**
```r
con <- dbConnect(
  PostgreSQL(),
  dbname = "S.E.A.L.",         #name of imported database
  port = 5432,               #port of imported server
  user = "postgres",         #username
  password = "password")     #password
```

<br> 

**Test a random query to check the connection.**
```r
test_query <- "SELECT 1"
test_result <- dbGetQuery(con, test_query)
if (!is.null(result)) {
  cat("Connection verified. Test query successful.\n")
} else {
  cat("Error: Connection test query failed.\n")
}
```

<br> 

**Disconnect**
```r
dbDisconnect(con)
```

<br> 

**Error**

The connection process should be the same for both Windows system and macOS system, however, but Windows users may encounter errors with the version of *libpq* in the *RPostgreSQL* package. However, it might occur when the *libpq* version is over 10. In this case, we need to alter the authetication from from *scram-sha-256* to another one, here we chose *md5*.

```r
RPosgreSQL error: 
could not connect postgres@localhost:5432 on dbname "S.E.A.L.": SCRAM authentication requires libpq version 10 or above
```

1. Check again if your libpq.dll files are over version 10, and have newest softwares (e.g. R, RPostgreSQL)
2. Close all the softwares and terminals.
3. Go to the install location of PostgreSQL, open folder *data*, you’ll see two conf files called *pg_hba* and *postgresql*.
4. Set *password_encryption = md5* in postgresql.conf
5. Set *METHODS* be *md5* in pg_hba.conf
6.  Open the prompt (SQL shell, or called psql), log in, change the password using the following command 
   ```psql
   ALTER USER here-is-your-username WITH PASSWORD 'here-is-your-new-password';
   ```
7. Reload the server of PostgreSQL, re log in to pgAdmin
8. Restart Rstudio, reconnect the server and it should work now 

<br> 

---

<br> 

## 4. Querying Examples

<br> 

**1. Select/exclude certain columns and/or rows**
  
<br>

Query all tables in the selected database
```r
tables <- dbListTables(con)
print(tables)
```

<br>

Get all information from the table "data_tags"
```r
initial.query <- "SELECT * FROM data_tags"
initial.table <- dbGetQuery(con, initial.query)
```

<br>

Get columns "specimen" and "bone" from the table "data_tags"
```r
query <- "SELECT specimen, bone FROM data_tags"
table <- dbGetQuery(con, query)
```

<br>

Get all rows having "ulna" in column "bone" from the table "data_tags"
```r
query <- "SELECT * FROM public.data_tags WHERE bone = 'ulna'"
table <- dbGetQuery(con, query)
```

<br>

Get columns "specimen" and "bone" from the table "data_tags", but only with rows having "A. pusilus_1" in column "specimen" and "rib" in column "bone"
```r
query <- "SELECT specimen, bone FROM public.data_tags
           WHERE specimen = 'Arctocephalus pusillus_1'
           AND bone = 'rib';"
table <- dbGetQuery(con, query)
```

<br>

Get all rows containing "ume" in column "bone" from the table "data_tags"
```r
query <- "SELECT * FROM data_tags
          WHERE bone like '%ume%';"
table <- dbGetQuery(con, query)
```

<br>

Get all rows containing "hum" in column "bone", with "hum" as the start
```r
query <- "SELECT * FROM data_tags
          WHERE bone like 'hum%';"
table <- dbGetQuery(con, query)
```

<br>

Get all rows containing "rus" in column "bone", with "rus" as the end
```r
query <- "SELECT * FROM data_tags
          WHERE bone like '%rus';"
table <- dbGetQuery(con, query)
```

<br>

Get all rows not containing "ume" in column "bone" from the table "data_tags"
```r
query <- "SELECT * FROM data_tags
          WHERE bone NOT like '%ume%';"
table <- dbGetQuery(con, query)
```

<br>

Get rows containing “1"，“2” and "3" in column "logic_tag" from the table "data_tags"
```r
query <- "SELECT * FROM data_tags
          WHERE logic_tag IN (1, 2, 3);"
table <- dbGetQuery(con, query)
```

<br>

Get rows not containing “rib"，“humerus” and "scapula" in column "bone" from the table "data_tags"
```r
query <- "SELECT * FROM data_tags
          WHERE bone NOT IN ('rib', 'humerus', 'scapula');"
table <- dbGetQuery(con, query)
```

<br>

Find a certain cell from table "data_tags" by giving a certain row and column
```r
query <- "SELECT bone FROM data_tags
          WHERE logic_tag = '19';"
table <- dbGetQuery(con, query)
```

<br> 
<br>

**2. Multiple conditions** 

<br>  

AND: both conditions are true
```r
query <- "SELECT * FROM data_tags
          WHERE specimen = 'Arctocephalus pusillus_1'
          AND bone = 'rib';"
table <- dbGetQuery(con, query)
```

<br>

OR: any condition should be true
```r
query <- "SELECT * FROM data_tags
          WHERE specimen = 'Arctocephalus pusillus_1'
          OR bone = 'humerus';"
table <- dbGetQuery(con, query)
```

<br>

AND & OR: in this case, either both specimen = 'Arctocephalus pusillus_1' is true, or both bone = 'humerus' and sex = 'female' are true
```r
query <- "SELECT * FROM data_tags
          WHERE specimen = 'Arctocephalus pusillus_1'
          OR bone = 'humerus'
          AND sex = 'female';"
table <- dbGetQuery(con, query)
```

<br>

IS NOT NULL: select rows that is not null in column "logic_tag" from the table "data_tags"
```r
query <- 'SELECT * FROM data_tags
          WHERE "logic_tag" IS NOT NULL;'
table <- dbGetQuery(con, query)
```

<br>

BETWEEN: select rows that is between 1 and 10 in column "logic_tag" from the table "data_tags"
```r
query <- "SELECT * FROM data_tags
          WHERE logic_tag BETWEEN 1 AND 10
          ORDER BY logic_tag;"
table <- dbGetQuery(con, query)
```

<br>  
<br>

**3. Order data (changes to tables in R only)**
   
<br>

Get ordered table "data_tags" based on "logic_tag" in ascending order
```r
query <- "SELECT * FROM data_tags ORDER BY logic_tag;"
```
Or
```r
query <- "SELECT * FROM data_tags ORDER BY specimen ASC;"
table <- dbGetQuery(con, query5)
```

<br>

Get ordered table "data_tags" based on "logic_tag" in descending order
```r
query <- "SELECT * FROM data_tags ORDER BY logic_tag DESC;"
table <- dbGetQuery(con, query)
```

<br>

Get ordered table "data_tags" based on "bone" first, then "logic_tag"
```r
query <- "SELECT * FROM data_tags ORDER BY bone,logic_tag;"
table <- dbGetQuery(con, query)
```

<br>
<br>

**4. Group data**

<br>

Check all "specimen"s by grouping
```r
query <- "SELECT specimen FROM msp GROUP BY specimen;"
table <- dbGetQuery(con, query)
```

<br>

Check all "specimen"s by grouping, and count each "specimen"
```r
query <- "SELECT specimen, count(1)
          FROM msp GROUP BY specimen;"
table <- dbGetQuery(con, query)
```

<br>

Check all "specimen"s from the table "data_tags", count each "specimen", and find the max/min number in their "logic_tag"
```r
query <- "SELECT specimen, count(1),max(logic_tag),min(logic_tag)
          FROM data_tags GROUP BY specimen;"
table <- dbGetQuery(con, query)
```

<br>

Limit the max "logic_tag" be smaller than 100
```r
query <- "SELECT specimen, count(1), max(logic_tag), min(logic_tag)
          FROM data_tags
          GROUP BY specimen
          HAVING max(logic_tag) < 100;"
table <- dbGetQuery(con, query)
```

<br>
<br>

**5. Join relational tables**

<br>  

Join two tables "data_tags" and "data_uncertainty" together, with the corresponding columns table1."bone" and table2."bone"
```r
query <- "SELECT *
          FROM data_tags 
          INNER JOIN data_uncertainty 
          ON data_tags.\"bone\" = data_uncertainty.\"bone\";"
table <- dbGetQuery(con, query)
```

<br>

Set "data_tags" and "data_uncertainty" as t1 and t2 in query
```r
query <- "SELECT *
          FROM data_tags AS t1
          INNER JOIN data_uncertainty AS t2
          ON t1.\"bone\" = t2.\"bone\";"
table <- dbGetQuery(con, query)
```


<br>
<br>

**6. Users**

<br>

Query the user documentation
```r
user.query <- "SELECT * FROM user_documentation"
user.table <- dbGetQuery(con, user.query)
```

<br>

---

<br>

## 5. Editing Examples

<br>

**Roll back commitment**

Use it to avoid editorial mistakes.

<br>

* Start editing
```r
dbBegin(con)
```

* Roll back
```r
dbRollback(con)
```

* Commit
```r
dbCommit(con)
```

* Disconnect
```r
dbDisconnect(con)
```

<br>

**1. Update data**

<br>

Set all rows in "sex" column into "male" from table "data_tags"
```r
query <- "UPDATE data_tags SET sex = 'male';"
dbExecute(con, query)
```

<br>

Set "sex" column of the "Cystophora cristata" row in "specimen" column to "male"
```r
query <- "UPDATE data_tags
          SET sex = 'female'
          WHERE specimen = 'Cystophora cristata';"
dbExecute(con, query)
```

<br>

Set a certain cell from table "data_tags" by giving a certain row and column
```r
query <- "UPDATE data_tags
          SET sex = 'female'
          WHERE logic_tag = '1';"
dbExecute(con, query)
```

<br>
<br>

**2. Insert data**

<br>

Insert a new row with "specimen" as "specimen"
```r
query <- "INSERT INTO public.data_tags (\"specimen\") VALUES ('specimen');"
dbExecute(con, query)
```

<br>

Insert a new column called "size" with the data type of integer
```r
query <- "ALTER TABLE data_tags ADD COLUMN size INTEGER"
dbExecute(con, query)
```

<br>
<br>

**3. Delete data**

<br>

Delete the table "data_tags"
```r
query <- "DELETE FROM data_tags"
dbExecute(con, query)
```

<br>

Delete "specimen" column from table "data_tags"
```r
query <- "ALTER TABLE data_tags DROP COLUMN specimen"
dbExecute(con, query)
```

<br>

Delete the "specimen" row in "specimen" column from table "data_tags"
```r
query <- "DELETE FROM data_tags
          WHERE specimen = 'specimen';"
dbExecute(con, query)
```

<br>
<br>

**4. Create tables**

<br>

Create the table named msp, including columns "specimen" and "picture_number" with data types "text" and "integer", add more columns as needed
```r
query <- "CREATE TABLE IF NOT EXISTS public.msp (
          specimen TEXT,
          picture_number INTEGER);"
dbExecute(con, query)
```

<br>

Create the table and set "picture_number" as the primary key
```r
query <- "CREATE TABLE IF NOT EXISTS public.msp (
          specimen TEXT,
          picture_number INTEGER,
          CONSTRAINT picture_number_pkey PRIMARY KEY (picture_number));"
dbExecute(con, query)
```

<br>
<br>

**5. Order data (changes to the table from the dataset)**

<br>

Get ordered table "data_tags" based on "logic_tag" in ascending order
```r
query <- "SELECT * FROM data_tags ORDER BY logic_tag;"
```
Or
```r
query <- "SELECT * FROM data_tags ORDER BY specimen ASC;"
table <- dbGetQuery(con, query5)
```

<br>

Get ordered table "data_tags" based on "logic_tag" in descending order
```r
query <- "SELECT * FROM data_tags ORDER BY logic_tag DESC;"
table <- dbGetQuery(con, query)
```

<br>

Get ordered table "data_tags" based on "bone" first, then "logic_tag"
```r
query <- "SELECT * FROM data_tags ORDER BY bone,logic_tag;"
table <- dbGetQuery(con, query)
```

<br>
<br>





