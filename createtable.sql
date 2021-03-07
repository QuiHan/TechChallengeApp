--CREATE DATABASE techappdb WITH OWNER = app ENCODING = 'UTF8' LC_COLLATE = 'en-US' LC_CTYPE = 'en-US' CONNECTION LIMIT = -1 TEMPLATE template0;
CREATE TABLE tasks ( id SERIAL PRIMARY KEY, completed boolean NOT NULL, priority integer NOT NULL, title text NOT NULL);
INSERT INTO tasks (completed, priority, title) VALUES(false, 0, '1st Task');
INSERT INTO tasks (completed, priority, title) VALUES(false, 0, '2nd Task');
INSERT INTO tasks (completed, priority, title) VALUES(false, 0, '3rd Task');