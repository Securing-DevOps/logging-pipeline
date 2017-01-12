# Logging Pipeline demo with Hindsight

This repository contains sample code to run experiments and demos with
hindsight. You can run the code here using the mozilla/hindsight docker
container, as follows:

```bash
$ docker run -it \
    -v $(pwd)/cfg:/app/cfg \
    -v $(pwd)/input:/app/input \
    -v $(pwd)/run:/app/run \
    -v $(pwd)/output:/app/output
    mozilla/hindsight
```

This will mount the local directories into the Docker container and execute
hindsight. Resulting data will be put into the `output` directory.
