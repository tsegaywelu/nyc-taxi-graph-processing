from neo4j import GraphDatabase

class Interface:
    def __init__(self, uri, user, password):
        self._driver = GraphDatabase.driver(uri, auth=(user, password), encrypted=False)
        self._driver.verify_connectivity()

    def close(self):
        self._driver.close()

    def create_graph(self, r_property):
        """Create a named GDS projection, or reuse it if it already exists."""
        if r_property not in ("distance", "fare", "weight"):
            raise ValueError("Unsupported relationship property")

        graph_name = f"{r_property}Graph"
        with self._driver.session() as session:
            exists = session.run(
                "CALL gds.graph.exists($name) YIELD exists RETURN exists",
                name=graph_name,
            ).single()["exists"]
            if exists:
                return graph_name

            if r_property == "weight":
                query = """
                    MATCH (pu:Location)-[r:TRIP]->(do:Location)
                    RETURN gds.graph.project(
                        $name, pu, do
                    ).graphName AS graphName
                    LIMIT 1
                """
            else:
                query = f"""
                    MATCH (pu:Location)-[r:TRIP]->(do:Location)
                    RETURN gds.graph.project(
                        $name, pu, do,
                        {{relationshipProperties: {{weight: r.{r_property}}}}}
                    ).graphName AS graphName
                    LIMIT 1
                """

            return session.run(
                query,
                name=graph_name
            ).single()["graphName"]


    def bfs(self, start_node, last_node):
        self.create_graph("weight")
        with self._driver.session() as session:
            return session.run(
                """
                MATCH (source:Location {name: $start_node})
                MATCH (target:Location {name: $last_node})
                CALL gds.bfs.stream('weightGraph', {
                    sourceNode: source,
                    targetNodes: [target]
                })
                YIELD path
                RETURN path
                """,
                start_node=int(start_node),
                last_node=int(last_node),
            ).data()

    def pagerank(self, max_iterations, weight_property):
        graph_name = self.create_graph(weight_property)
        with self._driver.session() as session:
            result = session.run(
                """
                CALL gds.pageRank.stream($graph_name, {
                    maxIterations: $max_iterations,
                    dampingFactor: 0.85,
                    relationshipWeightProperty: 'weight'
                })
                YIELD nodeId, score
                RETURN gds.util.asNode(nodeId).name AS name, score
                ORDER BY score DESC
                """,
                graph_name=graph_name,
                max_iterations=int(max_iterations),
            ).data()
            if not result:
                return []
            return [result[0], result[-1]]


