# b2pw

Convert bytes to password.

## Installation

```sh
$ make
$ make install
```
or
```sh
$ brew tap x13a/tap
$ brew install x13a/tap/b2pw
```

## Usage

```text
b2pw [-h|V]

[-h] * Print help and exit
[-V] * Print version and exit
```

## Example

```sh
~
❯ echo -n "test1" | b2pw
VhVsUo7wevh7ZjEHRxrGrOgo0iKJ7HSL
~
❯ echo -n "test1" | b2pw
VhVsUo7wevh7ZjEHRxrGrOgo0iKJ7HSL
~
❯ echo -n "test2" | b2pw
PrJEtKpcPLjjdcbvAw5Gvo9IDsZBOSqr
```
