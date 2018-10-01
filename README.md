# SpdEx

Spatial Prisoner's Dilemma Game (assuming random graph as a social network) implemented by Elixir.
Current version is not parallelized by Flow, but parallel calculation version will be definitely available in the near future.

## Installation

This package can be installed
by adding `spd_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:spd_ex, "~> 0.1.0"}
  ]
end
```
Then, in your terminal;

```shell
$ mix deps.get
```
to install dependencies.

## Usage
Open interactive Elixir shell with ```iex -S mix``` and Just type;

```shell
iex > SpdEx.main
```
After the calculation, you'll get an output file with csv format.
 
## Documentation

Documentation can be found at [https://hexdocs.pm/spd_ex](https://hexdocs.pm/spd_ex).

## License
Copyright © 2018 Keisuke Nagashima, released under MIT license.
