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

get '/currencies' => sub ($c) {
  my ($err, $currencies) = find_all_currencies();

  if (defined $err) {
    $c->app->log->error("Error while fetching currencies from DB: $err");

    my $error_response = {
      error   => 'Error reading currencies', 
      message => $err
    };

    $c->render(json => $error_response);

    return;
  }

  $c->app->log->info("Found " . scalar(@$currencies) . " currencies");

  foreach my $currency (@$currencies) {
    $currency->{name} = delete $currency->{full_name};
  }

  $c->render(json => $currencies);
};

get '/exchangeRates' => sub ($c) {
  my ($err, $exchange_rates) = find_all_exchange_rates();

  if (defined $err) {
    $c->app->log->error("Error while fetching exchange rates from DB: $err");

    my $error_response = {
      error   => 'Error reading exchange rates', 
      message => $err
    };

    $c->render(json => $error_response);

    return;
  }

  $c->app->log->info("Found " . scalar(@$exchange_rates) . " exchange rates");

  $c->render(json => $exchange_rates);
};

app->start;
