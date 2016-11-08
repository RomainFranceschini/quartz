# Quartz - A DEVS-based Modeling & Simulation Environment (WIP)

Quartz is a Crystal library for defining models and constructing discrete
event simulations based on the DEVS (Discrete EVent System Specification) and
some of its extensions (Parallel DEVS, DSDEVS). Its a Crystal port of
[DEVS-Ruby](https://github.com/devs-ruby)

This project is developed by a research group at University of Corsica, which
also maintains another M&S environment :
[DEVSimPy](https://github.com/capocchi/DEVSimPy).

## Status

This project is a **work in progress** and is in alpha stage.

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
  - [ ] Model serialization
  - [ ] Model runtime validation
  - [ ] Logging
  - [ ] Internal DSL
- Distributed simulations
  - [ ] MPI bindings
  - [ ] Optimistic simulators
  - [ ] Conservative simulators
- Schedulers
  - [x] Calendar queue
  - [ ] Ladder queue
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

## Suggested Reading

* Bernard P. Zeigler, Herbert Praehofer, Tag Gon Kim. *Theory of Modeling and Simulation*. Academic Press; 2 edition, 2000. ISBN-13: 978-0127784557

## Contributors

- [[romain1189]](https://github.com/[romain1189]) Romain Franceschini - creator, maintainer (Université de Corse Pasquale Paoli)

## License

This software is governed by the CeCILL-C license under French law and
abiding by the rules of distribution of free software.  You can use,
modify and/ or redistribute the software under the terms of the CeCILL-C
license as circulated by CEA, CNRS and INRIA at the following URL
"http://www.cecill.info".

The fact that you are presently reading this means that you have had
knowledge of the CeCILL-C license and that you accept its terms.
