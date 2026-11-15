# NYC Taxi Graph Processing with Neo4j

A containerized graph-processing project that transforms New York City taxi-trip records into a Neo4j graph and analyzes connections between taxi zones using **PageRank** and **Breadth-First Search (BFS)** from the Neo4j Graph Data Science (GDS) library.



## Overview

The project processes the **March 2022 NYC Yellow Taxi Trip Records**. It filters trips whose pickup and dropoff zones are in the Bronx and excludes trips with distance ≤ 0.1 miles or fare ≤ $2.50. The resulting graph represents taxi zones as nodes and individual trips as directed relationships.

```text
March 2022 Yellow Taxi Parquet
             |
             v
   Python / Pandas filtering
             |
             v
        Filtered CSV
             |
             v
    Neo4j graph import
             |
             v
    Location --TRIP--> Location
             |
             v
     GDS PageRank / BFS
```

## Technologies

- **Python 3** — ETL and graph-query interface
- **Pandas + PyArrow** — Parquet processing and filtering
- **Neo4j 2025.08.0** — graph database
- **Neo4j Graph Data Science 2.21.0** — graph projections and algorithms
- **Docker + Ubuntu 22.04** — reproducible environment

## Graph data model

| Element | Description |
| --- | --- |
| `(:Location {name})` | A taxi zone, identified by its integer location ID |
| `[:TRIP]` | Directed relationship from pickup zone to dropoff zone |
| `TRIP.distance` | Trip distance, stored as a float |
| `TRIP.fare` | Fare amount, stored as a float |
| `TRIP.pickup_dt` | Pickup timestamp |
| `TRIP.dropoff_dt` | Dropoff timestamp |

Multiple trips between the same pair of locations are preserved as separate relationships.

## Project structure

```text
.
├── Dockerfile        # Installs Neo4j/GDS and imports the data during build
├── data_loader.py    # Filters taxi records and creates graph data
├── interface.py      # GDS graph projections, PageRank and BFS
├── tester.py         # Local tests, if provided separately by the course
└── README.md
```

**Note:** The course-provided tester and assignment PDF should not be published without permission. The dataset is downloaded during the Docker build and is not committed to Git.

## Run locally

### Requirements

- Docker Desktop with its engine running
- Available host ports **7474** and **7687**
- Internet access for the initial Docker build
- Python 3 for running the local test script

### 1. Build the image

```bash
docker build -t nyc-taxi-graph .
```

The Dockerfile downloads the dataset, installs Neo4j and GDS, and runs the data loader as part of the build. The first build may take several minutes.

### 2. Start Neo4j

```bash
docker run -d --name nyc-taxi-graph \
  -p 7474:7474 -p 7687:7687 \
  nyc-taxi-graph
```

Check the container:

```bash
docker ps
docker logs nyc-taxi-graph
```

### 3. Connect to Neo4j

Open [Neo4j Browser](http://localhost:7474) and connect to `bolt://localhost:7687` with the credentials configured in the Dockerfile.

> **Security note:** The course starter configuration uses a fixed local-development password. Do not expose this container publicly or reuse that password for production deployments.

### 4. Verify the graph

Run these queries in Neo4j Browser:

```cypher
MATCH (n:Location)
RETURN count(n) AS locations;
```

```cypher
MATCH ()-[r:TRIP]->()
RETURN count(r) AS trips;
```

Expected results for the provided filtering rules:

| Metric | Expected |
| --- | ---: |
| Location nodes | 42 |
| TRIP relationships | 1,530 |

## Graph algorithms

### PageRank

`Interface.pagerank(max_iterations, weight_property)` projects a directed graph using either `distance` or `fare` as its relationship weight, runs GDS PageRank with damping factor **0.85**, and returns the highest- and lowest-ranked locations with their scores.

### Breadth-First Search (BFS)

`Interface.bfs(start_node, last_node)` performs a directed, unweighted GDS BFS traversal from a source location toward a target location and returns the resulting path data.

## Testing

The local course-provided test suite was run against a Docker-hosted Neo4j instance:

| Area | Result |
| --- | ---: |
| Data loading | 10/10 |
| PageRank | 25/25 |
| BFS | 25/25 |
| **Functional tests** | **60/60** |

The Dockerfile is evaluated separately for an additional **40 points**; a full project grade has not been verified.

If you have the course-provided `tester.py` locally, install its dependencies and run:

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install neo4j requests
python3 tester.py
```

## Limitations and considerations

- Graph projections are cached by name; recreate them when underlying data changes.
- Re-running the data loader against the same populated database can duplicate trip relationships.
- The Docker configuration is intended for local coursework and is not production hardened.
- The initial build requires downloads from external sources.

## Data source

[NYC Taxi & Limousine Commission — Trip Record Data](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page) · [March 2022 Yellow Taxi Parquet](https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2022-03.parquet)

## License and academic integrity

No license is granted for redistribution of course-provided materials. Keep the repository private until the course rules permit sharing the implementation.
