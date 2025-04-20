#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use DBI;
use DBD::SQLite::Constants ':dbd_sqlite_string_mode';

my $data_source = 'DBI:SQLite:dbname=database.sqlite';
my $username = '';
my $password = '';
my $attr = {
  RaiseError => 1, 
  PrintError => 0,
  sqlite_string_mode => DBD_SQLITE_STRING_MODE_UNICODE_STRICT 
};

our $db_connection = DBI->connect($data_source, $username, $password, $attr) or die $DBI::errstr;

sub find_all_currencies {
  my $currencies;

  eval {
    my $statement = $db_connection->prepare('SELECT * FROM Currencies');
    $statement->execute();

    my @rows;
    while (my $row = $statement->fetchrow_hashref()) {
      push(@rows, $row);
    }

    $currencies = \@rows;
  };

  if ($@) {
    app->log->error("Database call error: $@");
    return (DBI::errstr, undef);
  }

  return (undef, $currencies);
}

sub find_currency_by_code ($code) {
  my $currency;

  eval {
    my $statement = $db_connection->prepare('SELECT * FROM Currencies WHERE code = ?');
    $statement->execute($code);

    $currency = $statement->fetchrow_hashref();

    if (!defined $currency) {
      return;
    }
  };

  if ($@) {
    app->log->error("Database call error: $@");
    return (DBI::errstr, undef);
  }

  return (undef, $currency);
}

sub save_currency ($name, $code, $sign) {
  my $currency;

  eval {
    my $statement = $db_connection->prepare('INSERT INTO Currencies (full_name, code, sign) VALUES (?, ?, ?) RETURNING *');
    $statement->execute($name, $code, $sign);

    $currency = $statement->fetchrow_hashref();
  };

  if ($@) {
    app->log->error("Database call error: $@");
    return (DBI::errstr, undef);
  }

  return (undef, $currency);
}

sub find_all_exchange_rates {
  my $exchage_rates;

  eval {
    my $query = '
    SELECT 
      e.id AS id,
      b.id AS b_id, b.code AS b_code, b.full_name AS b_full_name, b.sign AS b_sign,
      t.id AS t_id, t.code AS t_code, t.full_name AS t_full_name, t.sign AS t_sign,
      e.rate AS rate
    FROM Exchange_rates e
      JOIN Currencies b ON e.base_currency_id = b.id
      JOIN Currencies t ON e.target_currency_id = t.id';

    my $statement = $db_connection->prepare($query);
    $statement->execute();

    my @rows;
    while (my $row = $statement->fetchrow_hashref()) {
      push(@rows, $row);
    }

    @rows = [
      map { 
        { 
          id => $_->{id},
          rate => $_->{rate},
          baseCurrency => {
            id   => $_->{b_id},
            name => $_->{b_full_name},
            code => $_->{b_code},
            sign => $_->{b_sign},
          },
          targetCurrency => {
            id   => $_->{t_id},
            name => $_->{t_full_name},
            code => $_->{t_code},
            sign => $_->{t_sign},
          }
        } 
      } @rows 
    ];

    $exchage_rates = \@rows;
  };

  if ($@) {
    app->log->error("Database call error: $@");
    return (DBI::errstr, undef);
  }

  return (undef, $exchage_rates);
}

sub find_exchange_rate_by_codes ($base_code, $target_code) {
  my $exchange_rate;

  eval {
    my $query = '
    SELECT 
      e.id AS id,
      b.id AS b_id, b.code AS b_code, b.full_name AS b_full_name, b.sign AS b_sign,
      t.id AS t_id, t.code AS t_code, t.full_name AS t_full_name, t.sign AS t_sign,
      e.rate AS rate
    FROM Exchange_rates e
      JOIN Currencies b ON e.base_currency_id = b.id
      JOIN Currencies t ON e.target_currency_id = t.id
    WHERE b.code = ? AND t.code = ?';

    my $statement = $db_connection->prepare($query);
    $statement->execute($base_code, $target_code);

    $exchange_rate = $statement->fetchrow_hashref();

    if (!defined $exchange_rate) {
      return;
    }

    $exchange_rate = { 
      id => $exchange_rate->{id},
      rate => $exchange_rate->{rate},
      baseCurrency => {
        id   => $exchange_rate->{b_id},
        name => $exchange_rate->{b_full_name},
        code => $exchange_rate->{b_code},
        sign => $exchange_rate->{b_sign},
      },
      targetCurrency => {
        id   => $exchange_rate->{t_id},
        name => $exchange_rate->{t_full_name},
        code => $exchange_rate->{t_code},
        sign => $exchange_rate->{t_sign},
      }
    } 
  };

  if ($@) {
    app->log->error("Database call error: $@");
    return (DBI::errstr, undef);
  }

  return (undef, $exchange_rate);
}

sub save_exchange_rate_for ($base_currency_code, $target_currency_code, $rate) {
  eval {
    my $query = '
      INSERT INTO Exchange_rates (base_currency_id, target_currency_id, rate)
      VALUES (
        (SELECT id FROM Currencies WHERE code = ?),
        (SELECT id FROM Currencies WHERE code = ?),
        ?
      )';

    my $statement = $db_connection->prepare($query);

    $statement->execute($base_currency_code, $target_currency_code, $rate);
  };

  if ($@) {
    app->log->error("Database call error: $@");
    return (DBI::errstr, undef);
  }

  return (undef, undef);
}

sub update_exchange_rate_for ($base_currency_code, $target_currency_code, $rate) {
  eval {
    my $query = '
      UPDATE Exchange_rates
      SET rate = ?
      WHERE base_currency_id = (SELECT id FROM Currencies WHERE code = ?)
      AND target_currency_id = (SELECT id FROM Currencies WHERE code = ?)';

    my $statement = $db_connection->prepare($query);

    $statement->execute($rate, $base_currency_code, $target_currency_code);
  };

  if ($@) {
    app->log->error("Database call error: $@");
    return (DBI::errstr, undef);
  }

  return (undef, undef);
}

get '/currencies' => sub ($c) {
  my ($err, $currencies) = find_all_currencies();

  if (defined $err) {
    $c->app->log->error("Error while fetching currencies from DB: $err");

    my $error_response = {
      error   => 'Error reading currencies', 
      message => $err
    };

    $c->render(status => 500, json => $error_response);

    return;
  }

  $c->app->log->info("Found " . scalar(@$currencies) . " currencies");

  foreach my $currency (@$currencies) {
    $currency->{name} = delete $currency->{full_name};
  }

  $c->render(status => 200, json => $currencies);
};

get '/currency/:code' => sub ($c) {
  my $code = $c->param('code');

  unless ($code =~ /^[A-Z]{3}$/) {
    $c->app->log->error("Ivalid parameter code = $code");

    my $error_response = {
      error   => 'Invalid currency code format',
      message => 'Currency code must be in the ISO-4217 format'
    };

    return $c->render(status => 400, json => $error_response);
  }

  my ($err, $currency) = find_currency_by_code($code);

  if (defined $err) {
    $c->app->log->error("Error while fetching currency from DB: $err");

    my $error_response = {
      error   => 'Error reading currency', 
      message => $err
    };

    $c->render(status => 500, json => $error_response);

    return;
  }
  if (!defined $currency) {
    $c->app->log->error("Currency $code not found");

    my $error_response = {
      error   => 'Not Found', 
      message => "Currency $code not found"
    };

    $c->render(status => 404, json => $error_response);

    return;
  }

  $c->app->log->info("Found " . $currency->{code} . " currency");

  $currency->{name} = delete $currency->{full_name};

  $c->render(status => 200, json => $currency);
};

post '/currencies' => sub ($c) {
  my $name = $c->param('name');
  my $code = $c->param('code');
  my $sign = $c->param('sign');

  unless (defined $name || defined $code || defined $sign) {
    $c->app->log->error("Parameter(s) missing; name = $name, code = $code, sign = $sign");

    my $error_response = {
      error   => 'Missing required paramters', 
      message => 'Missing required paramters'
    };

    $c->render(status => 400, json => $error_response);

    return;
  }

  my ($err, $currency) = save_currency($name, $code, $sign);

  if (defined $err) {
    $c->app->log->error("Error while saving currency to DB: $err");

    my $error_response = {
      error   => 'Error saving currency', 
      message => $err
    };

    $c->render(status => 500, json => $error_response);

    return;
  }

  $c->app->log->info("Saved " . $currency->{code} . " currency");

  $currency->{name} = delete $currency->{full_name};

  $c->render(status => 201, json => $currency);
};

get '/exchangeRates' => sub ($c) {
  my ($err, $exchange_rates) = find_all_exchange_rates();

  if (defined $err) {
    $c->app->log->error("Error while fetching exchange rates from DB: $err");

    my $error_response = {
      error   => 'Error reading exchange rates', 
      message => $err
    };

    $c->render(status => 500, json => $error_response);

    return;
  }

  $c->app->log->info("Found " . scalar(@$exchange_rates) . " exchange rates");

  $c->render(status => 200, json => $exchange_rates);
};

get '/exchangeRate/:codes' => sub ($c) {
  my $codes = $c->param('codes');

  unless ($codes =~ /^([A-Z]{3})([A-Z]{3})$/) {
    $c->app->log->error("Invalid parameter codes = $codes");

    my $error_response = {
      error   => 'Invalid currency pair format',
      message => 'Currency codes must be in the ISO-4217 format'
    };

    $c->render(status => 400, json => $error_response);

    return;
  }

  my ($base_code, $target_code) = ($1, $2);

  my ($err, $exchange_rate) = find_exchange_rate_by_codes($base_code, $target_code);

  if (defined $err) {
    $c->app->log->error("Error while fetching exchange rate from DB: $err");

    my $error_response = {
      error   => 'Error reading exchange rate', 
      message => $err
    };

    $c->render(status => 500, json => $error_response);

    return;
  }
  if (!defined $exchange_rate) {
    $c->app->log->error("Exchange rate $base_code -> $target_code not found");

    my $error_response = {
      error   => 'Not Found', 
      message => "Exchange rate $base_code -> $target_code not found"
    };

    $c->render(status => 404, json => $error_response);

    return;
  }

  $c->app->log->info("Found $base_code -> $target_code exchange rate");

  $c->render(status => 200, json => $exchange_rate);
};

post '/exchangeRates' => sub ($c) {
  my $base_currency_code = $c->param('baseCurrencyCode');
  my $target_currency_code = $c->param('targetCurrencyCode');
  my $rate = $c->param('rate');

  unless ($base_currency_code =~ /^[A-Z]{3}$/ || $target_currency_code =~ /^[A-Z]{3}$/) {
    $c->app->log->error("Invalid currency code parameter; baseCurrencyCode = $base_currency_code, targetCurrencyCode = $target_currency_code");

    my $error_response = {
      error   => 'Invalid currency code format',
      message => 'Currency codes must be in the ISO-4217 format'
    };

    $c->render(status => 400, json => $error_response);

    return;
  }

  my ($err, $res) = save_exchange_rate_for($base_currency_code, $target_currency_code, $rate);

  if (defined $err) {
    $c->app->log->error("Error while saving exchange rate $base_currency_code -> $target_currency_code");

    my $error_response = {
      error   => 'Error saving exchange rate', 
      message => $err
    };

    $c->render(status => 500, json => $error_response);

    return;
  }

  ($err, my $exchange_rate) = find_exchange_rate_by_codes($base_currency_code, $target_currency_code);

  if (defined $err) {
    $c->app->log->error("Error while saving exchange rate $base_currency_code -> $target_currency_code");

    my $error_response = {
      error   => 'Error saving exchange rate', 
      message => $err
    };

    $c->render(status => 500, json => $error_response);

    return;
  }

  if (!defined $exchange_rate) {
    $c->app->log->error("Error while saving exchange rate $base_currency_code -> $target_currency_code");

    my $error_response = {
      error   => 'Error saving exchange rate', 
      message => $err
    };

    $c->render(status => 500, json => $error_response);

    return;
  }

  $c->app->log->info("Saved $base_currency_code -> $target_currency_code exchange rate");

  $c->render(status => 201, json => $exchange_rate);
};

patch '/exchangeRate/:codes' => sub ($c) {
  my $codes = $c->param('codes');
  my $rate = $c->param('rate');

  unless ($codes =~ /^([A-Z]{3})([A-Z]{3})$/) {
    $c->app->log->error("Invalid parameter codes = $codes");

    my $error_response = {
      error   => 'Invalid currency pair format',
      message => 'Currency codes must be in the ISO-4217 format'
    };

    $c->render(status => 400, json => $error_response);

    return;
  }

  my ($base_code, $target_code) = ($1, $2);

  my ($err, $res) = update_exchange_rate_for($base_code, $target_code, $rate);

  if (defined $err) {
    $c->app->log->error("Error while updating exchange rate $base_code -> $target_code");

    my $error_response = {
      error   => "Error updating exchange rate $base_code -> $target_code", 
      message => $err
    };

    $c->render(status => 500, json => $error_response);

    return;
  }

  ($err, my $exchange_rate) = find_exchange_rate_by_codes($base_code, $target_code);

  if (defined $err) {
    $c->app->log->error("Error while updating exchange rate $base_code -> $target_code");

    my $error_response = {
      error   => "Error updating exchange rate $base_code -> $target_code", 
      message => $err
    };

    $c->render(status => 500, json => $error_response);

    return;
  }

  if (!defined $exchange_rate) {
    $c->app->log->error("Error while saving exchange rate $base_code -> $target_code");

    my $error_response = {
      error   => "Error updating exchange rate $base_code -> $target_code", 
      message => $err
    };

    $c->render(status => 500, json => $error_response);

    return;
  }

  $c->app->log->info("Updated $base_code -> $target_code exchange rate");

  $c->render(status => 200, json => $exchange_rate);
};

get '/exchange' => sub ($c) {
  my $base_code = $c->param('from');
  my $target_code = $c->param('to');
  my $amount = $c->param('amount');

  unless ($base_code =~ /^[A-Z]{3}$/ || $target_code =~ /^[A-Z]{3}$/) {
    $c->app->log->error("Invalid currency code parameter; from = $base_code, to = $target_code");

    my $error_response = {
      error   => 'Invalid currency code format',
      message => 'Currency codes must be in the ISO-4217 format'
    };

    $c->render(status => 400, json => $error_response);

    return;
  }

  my ($err, $exchange_rate) = find_exchange_rate_by_codes($base_code, $target_code);

  if (defined $err) {
    $c->app->log->error("Error while fetching exchange rates from DB: $err");

    my $error_response = {
      error   => 'Error reading exchange rates', 
      message => $err
    };

    $c->render(status => 500, json => $error_response);

    return;
  }

  if (!defined $exchange_rate) {
    $c->app->log->error("Exchange rate $base_code -> $target_code not found");

    my $error_response = {
      error   => 'Not Found', 
      message => "Exchange rate $base_code -> $target_code not found"
    };

    $c->render(status => 404, json => $error_response);

    return;
  }

  my $converted_amount = $amount * $exchange_rate->{rate};

  $c->app->log->info("Converted $amount $base_code -> $converted_amount $target_code");

  my $conversion_result = {
    baseCurrency    => $exchange_rate->{baseCurrency},
    targetCurrency  => $exchange_rate->{targetCurrency},
    rate            => $exchange_rate->{rate},
    amount          => $amount,
    convertedAmount => $converted_amount
  };

  $c->render(status => 200, json => $conversion_result);
};

app->start;
