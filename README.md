# Currency Exchange API

[![Perl](https://img.shields.io/badge/perl-black?style=for-the-badge&logo=perl)](https://www.perl.org/)
[![Mojolicious](https://img.shields.io/badge/mojolicious-black?style=for-the-badge&logo=mojolicious)](https://www.mojolicious.org)


![GitHub License](https://img.shields.io/github/license/krios2146/currency-exchange-api-perl?style=flat-square&labelColor=black&color=black)

Simple REST API with currencies and exchange rates as resources and exchange of the currency as the main functionality

Created according to the technical specifications presented in [this course](https://zhukovsd.github.io/java-backend-learning-course/projects/currency-exchange)

## Run Locally

> [!IMPORTANT]  
> [Perl](https://www.perl.org/get.html) and [Perlbrew](https://perlbrew.pl) should be installed to run this project

Clone the project

```bash
git clone git@github.com:krios2146/krios2146/currency-exchange-api-perl.git
```

Go to the project directory

```bash
cd krios2146/currency-exchange-api-perl
```

Install perl in isolation from the system perl

```bash
perlbrew install perl-5.40.2
```

Switch to installed perl (beware, command will switch perl for all terminal sessions)

```bash
perlbrew switch perl-5.40.2
```

Install cpanm tool for perlbrew

```bash
perlbrew install-cpanm
```

Create virtualenv like environment for project 

```bash
perlbrew lib create currency-exchange-api
```

Switch to isolated project environment

```bash
perlbrew switch perl-5.40.2@currency-exchange-api
```

Install deps via cpanm

```bash
cpanm --installdeps .
```

Run dev server with 

```bash
morbo ./main.pl
```

## API Reference
> [!NOTE]  
> [Postman workspace](https://www.postman.com/krios2185/workspace/currency-exchange-workspace) for this project with reuqests examples

### Currencies

#### Get all currencies

```http
GET /currencies
```

#### Get currency by code

```http
GET /currency/:code
```

| Parameter | Type     | Description                                                                                  |
|:----------|:---------|:---------------------------------------------------------------------------------------------|
| `code`    | `string` | **Required**. Currency code in the [ISO-4217](https://en.wikipedia.org/wiki/ISO_4217) format |

#### Add new currency

```http
POST /currencies
Content-Type: x-www-form-urlencoded
```

| Request | Type     | Description                                                                                  |
|:--------|:---------|:---------------------------------------------------------------------------------------------|
| `code`  | `string` | **Required**. Currency code in the [ISO-4217](https://en.wikipedia.org/wiki/ISO_4217) format |
| `name`  | `string` | **Required**. Currency name                                                                  |
| `sign`  | `string` | **Required**. Currency sign                                                                  |

### Exchange Rates

#### Get all exchange rates

```http
GET /exchangeRates
```

#### Get exchange rate for currencies

```http
GET /exchangeRate/:codes
```

| Parameter | Type     | Description                                                                                                                                                                |
|:----------|:---------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `codes`   | `string` | **Required**. Currency codes in the [ISO-4217](https://en.wikipedia.org/wiki/ISO_4217) format. E.g. for `USDEUR` parameter API will response with USD => EUR exchange rate |

#### Add new exchange rate

```http
POST /exchangeRates
Content-Type: x-www-form-urlencoded
```

| Request              | Type     | Description                                                                                         |
|:---------------------|:---------|:----------------------------------------------------------------------------------------------------|
| `baseCurrencyCode`   | `string` | **Required**. Base currency code in the [ISO-4217](https://en.wikipedia.org/wiki/ISO_4217) format   |
| `targetCurrencyCode` | `string` | **Required**. Target currency code in the [ISO-4217](https://en.wikipedia.org/wiki/ISO_4217) format |
| `rate`               | `float`  | **Required**. Exchange rate                                                                         |

#### Update exchange rate for currencies

```http
PATCH /exchangeRate/:codes
Content-Type: x-www-form-urlencoded
```

| Parameter/Request | Type     | Description                                                                                                                                                         |
|:------------------|:---------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `codes`           | `string` | **Required**. Currency codes in the [ISO-4217](https://en.wikipedia.org/wiki/ISO_4217) format. E.g. for `USDEUR` parameter API will update USD => EUR exchange rate |
| `rate`            | `float`  | **Required**. New exchange rate for currency pair                                                                                                                   |

### Currency exchange

```http
GET /exchange
```

| Query    | Type     | Description                                                                           |
|:---------|:---------|:--------------------------------------------------------------------------------------|
| `from`   | `string` | **Required**. Currency code in the [ISO-4217](https://en.wikipedia.org/wiki/ISO_4217) |
| `to`     | `string` | **Required**. Currency code in the [ISO-4217](https://en.wikipedia.org/wiki/ISO_4217) |
| `amount` | `float`  | **Required**. Amount to exchange                                                      |
