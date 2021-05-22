# Quartz - A Crystal Modeling & Simulation Framework

[![CI Status](https://github.com/RomainFranceschini/quartz/workflows/Quartz%20CI/badge.svg?branch=master)](https://github.com/RomainFranceschini/quartz/actions)

Quartz is a Crystal library for defining models and constructing discrete
event simulations.

The following features are supported:

- Hierarchical models, through the coupling of sub-models via their input/output ports.
- Discrete-event and discrete-time models.
- Dynamic structure models.
- A precise representation of the simulated time.
- Heterogeneous models, *e.g.* coupling discrete-event and discrete-time models.
- Model and / or ports observers.
- Simulation hooks.

## Documentation

* [Docs](https://github.com/RomainFranceschini/quartz/wiki)
* [API](https://romainfranceschini.github.io/quartz/)

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
    github: RomainFranceschini/quartz
```

Then, resolve dependencies with shards (Crystal dependency manager) to install Quartz as a dependency of your project:

```
$ shards install
```

### Usage

See the [examples](examples) folder.

## Underlying theory

Quartz is based on the PDEVS (Parallel Discrete EVent System Specification) formalism and some of its extensions (DTSS, DSDE, multiPDEVS).

This project is developed by a research group at University of Corsica.

### Related books/papers

- Zeigler, Bernard P, Alexandre Muzy, and Ernesto Kofman. 2019. *Theory of Modeling and Simulation*. 3rd edition. Discrete Event & Iterative System Computational Foundations. Academic Press. [DOI: 10.1016/C2016-0-03987-6](https://doi.org/10.1016/C2016-0-03987-6).
- Foures, Damien, Romain Franceschini, Paul-Antoine Bisgambiglia, et Bernard P. Zeigler. 2018. « *MultiPDEVS: A Parallel Multicomponent System Specification Formalism* ». Complexity 2018: 1‑19. [DOI: 10.1155/2018/3751917](https://doi.org/10.1155/2018/3751917).
- Franceschini, Romain, Paul-Antoine Bisgambiglia, Paul Bisgambiglia, and David R. C. Hill. 2018. « *An Overview of the Quartz Modelling and Simulation Framework* ». In Proceedings of 8th International Conference on Simulation and Modeling Methodologies, Technologies and Applications, 120‑27. Porto, Portugal: SCITEPRESS - Science and Technology Publications. [DOI: 10.5220/0006864201200127](https://doi.org/10.5220/0006864201200127)
- Goldstein, Rhys, Azam Khan, Olivier Dalle, et Gabriel Wainer. 2018. « *Multiscale Representation of Simulated Time* ». SIMULATION 94 (6): 519‑58. [DOI: 10.1177/0037549717726868](https://doi.org/10.1177/0037549717726868).

### Alternatives

Many other tools allow modeling and simulation based on the DEVS theory. Here is a non-exhaustive list:
- [VLE](http://www.vle-project.org) (Virtual Laboratory Environment)
- [ADEVS](http://web.ornl.gov/~1qn/adevs/)
- [PythonPDEVS](http://msdl.cs.mcgill.ca/projects/DEVS/PythonPDEVS)
- [CD++](http://cell-devs.sce.carleton.ca/mediawiki/index.php/Main_Page)
- [PowerDEVS](https://sourceforge.net/projects/powerdevs/)
- [DEVS-Suite](http://acims.asu.edu/software/devs-suite/)
- [MS4Me](http://www.ms4systems.com)
- [James II](http://jamesii.informatik.uni-rostock.de/jamesii.org/)

## Contributors

- [[RomainFranceschini]](https://github.com/RomainFranceschini) Romain Franceschini - creator, maintainer (University of Corsica Pasquale Paoli)

## Contributing

1. Fork it (https://github.com/RomainFranceschini/quartz/fork)
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
