CREATE TABLE IF NOT EXISTS Exchange_rates (
    id                  INTEGER PRIMARY KEY,
    base_currency_id    varchar NOT NULL,
    target_currency_id  varchar NOT NULL,
    rate                real NOT NULL,

    UNIQUE(base_currency_id, target_currency_id),
    FOREIGN KEY(base_currency_id) REFERENCES Currencies(id),
    FOREIGN KEY(target_currency_id) REFERENCES Currencies(id)
);
