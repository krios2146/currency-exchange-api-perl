CREATE TABLE IF NOT EXISTS Currencies (
    id          INTEGER PRIMARY KEY,
    code        varchar UNIQUE NOT NULL,
    full_name   varchar NOT NULL,
    sign        varchar NOT NULL,

    CHECK (length(code) == 3)
);
