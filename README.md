# Quartz - A DEVS-based Modeling & Simulation Environment (WIP)

[![Build Status](https://travis-ci.org/romain1189/quartz.svg?branch=master)](https://travis-ci.org/romain1189/quartz)

Quartz is a Crystal library for defining models and constructing discrete
event simulations based on the PDEVS (Parallel Discrete EVent System Specification) and
some of its extensions (DSDE, multiPDEVS). Its a Crystal port of
[DEVS-Ruby](https://github.com/devs-ruby)

This project is developed by a research group at University of Corsica, which
also maintains another M&S environment :
[DEVSimPy](https://github.com/capocchi/DEVSimPy).

## Status

This project is a **work in progress** and is in alpha stage.

## Installation

### Requirements 

* Crystal. Please refer to <http://crystal-lang.org/docs/installation> for
  instructions for your operating system.

### Setup

Crystal applications and libraries are expected to have a `shard.yml` file
at their root. Create a `shard.yml` file in your project's folder (or add to it) with the following contents:

```yaml
dependencies:
  quartz:
    github: romain1189/quartz
    version: 0.1.0
```

Replace the version *0.1.0* with the actual version of Quartz you wish to use.

Then, resolve dependencies with shards (Crystal dependency manager) to install Quartz and its requirements as a dependency of your project:

```
$ crystal deps
```

### Usage

```crystal
require "quartz"

class LotkaVolterra < Quartz::AtomicModel
  state_var x : Float64 = 1.0
  state_var y : Float64 = 1.0
  state_var alpha : Float64 = 5.2     # prey reproduction rate
  state_var beta : Float64 = 3.4      # predator per prey mortality rate
  state_var gamma : Float64 = 2.1     # predator mortality rate
  state_var delta : Float64 = 1.4     # predator per prey reproduction rate

  @sigma = 0.0001                     # euler integration

  def internal_transition
    dxdt = ((@x * @alpha) - (@beta * @x * @y))
    dydt = (-(@gamma * @y) + (@delta * @x * @y))

    @x += @sigma * dxdt
    @y += @sigma * dydt
  end
end

model = LotkaVolterra.new(:lotka)
sim = Quartz::Simulation.new(model, duration: 20)
sim.simulate
```

```
$ crystal build lotka.cr
$ ./lotka
```

### More examples

See the [examples](examples) folder.

## Getting the code

- Install Crystal compiler (<http://crystal-lang.org/docs/installation>)
- Clone the git repository (`git clone git://github.com/romain1189/quartz.git`).
- Resolves dependencies (`cd quartz; crystal deps`).
- Run specs (`crystal spec`).
- Build examples (`crystal build examples/*.cr`)/

## Development

TODO List:
- Supported formalisms
  - [x] Parallel DEVS
  - [x] DSDE
  - [x] MultiPDEVS
  - [ ] CellDEVS
  - [ ] QSS
- Features
  - [x] Port observers
  - [x] Transition observers
  - [x] Simulation hooks
  - [x] Hierarchy flattening
  - [x] Graphviz output of coupled structure
  - [x] Class-level definition of ports (through macros)
  - [x] Model serialization
  - [x] Model runtime validation (WIP)
  - [x] Logging
  - [ ] Internal DSL
  - [x] Scheduler hint
- Distributed simulations
  - [x] MPI bindings (WIP, see [mpi.cr](https://github.com/romain1189/mpi.cr) repository)
  - [ ] Optimistic simulators
  - [ ] Conservative simulators
- Schedulers
  - [x] Calendar queue
  - [x] Ladder queue
  - [ ] Binary heap
  - [ ] Splay tree
- Documentation
  - Better documentation
- Tests
  - Better test coverage
- Debug schedulers and introduce better meta-model
- Better virtual time representation

## Differences with [DEVS-Ruby](https://github.com/devs-ruby)

Classic DEVS is not supported.

## Alternatives

Many other tools allow modeling and simulation based on the DEVS theory. Here is a non-exhaustive list:
- [VLE](http://www.vle-project.org) (Virtual Laboratory Environment)
- [ADEVS](http://web.ornl.gov/~1qn/adevs/)
- [PythonPDEVS](http://msdl.cs.mcgill.ca/projects/DEVS/PythonPDEVS)
- [CD++](http://cell-devs.sce.carleton.ca/mediawiki/index.php/Main_Page)
- [PowerDEVS](https://sourceforge.net/projects/powerdevs/)
- [DEVS-Suite](http://acims.asu.edu/software/devs-suite/)
- [MS4Me](http://www.ms4systems.com)
- [James II](http://jamesii.informatik.uni-rostock.de/jamesii.org/)

## Suggested Reading

* Bernard P. Zeigler, Herbert Praehofer, Tag Gon Kim. *Theory of Modeling and Simulation*. Academic Press; 2 edition, 2000. ISBN-13: 978-0127784557

## Contributors

- [[romain1189]](https://github.com/[romain1189]) Romain Franceschini - creator, maintainer (Université de Corse Pasquale Paoli)

## Contributing

1. Fork it (https://github.com/romain1189/quartz/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new pull request.

## License

This software is governed by the CeCILL-C license under French law and
abiding by the rules of distribution of free software.  You can use,
modify and/ or redistribute the software under the terms of the CeCILL-C
license as circulated by CEA, CNRS and INRIA at the following URL
"http://www.cecill.info".

The fact that you are presently reading this means that you have had
knowledge of the CeCILL-C license and that you accept its terms.
