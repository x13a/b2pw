# b2pw

Convert bytes to password.

Main purpose is to convert files to passwords. You can take any file and convert it 
to password up to 64 chars long. First we make hash of it using `blake2b`, than
map each result byte to our alphabet. On the same file you always get the same password.

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
b2pw [-hV] [-l NUM] [-a STR] [-k STR] [-c STR] [-n NUM]

[-h] * Print help and exit
[-V] * Print version and exit

[-l] * Length of password (default: 32)
[-a] * Alphabet (default: abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789)
[-k] * Key (default: null)
[-c] * Additional chars (default: "")
[-n] * Number of bytes to read (default: 0 = all)
```

## Example

```sh
~
❯ echo -n "test1" | b2pw
RQ3sDNrPzzkiVLYsqRzsnQTkgbK4cm0U
~
❯ echo -n "test1" | b2pw
RQ3sDNrPzzkiVLYsqRzsnQTkgbK4cm0U
~
❯ echo -n "test2" | b2pw
KS4qquoEFhN4XJiECDcQZxJXca6ZrKCN
```
