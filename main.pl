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

app->start;
