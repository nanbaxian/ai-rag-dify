from pydantic import Field, PositiveInt
from pydantic_settings import BaseSettings


class WeaviateConfig(BaseSettings):
    """
    Configuration settings for Weaviate vector database
    """

    WEAVIATE_ENDPOINT: str | None = Field(
        description="URL of the Weaviate server (e.g., 'http://localhost:8080' or 'https://weaviate.example.com')",
        default=None,
    )

    WEAVIATE_USE_EMBEDDED: bool = Field(
        description=(
            "Run an embedded local Weaviate instance from the Python client instead of connecting to a separate "
            "server. This is intended for Ubuntu server deployments and other Linux environments."
        ),
        default=False,
    )

    WEAVIATE_EMBEDDED_VERSION: str | None = Field(
        description="Version of the embedded Weaviate binary to start when WEAVIATE_USE_EMBEDDED is enabled.",
        default=None,
    )

    WEAVIATE_API_KEY: str | None = Field(
        description="API key for authenticating with the Weaviate server",
        default=None,
    )

    WEAVIATE_GRPC_ENDPOINT: str | None = Field(
        description="URL of the Weaviate gRPC server (e.g., 'grpc://localhost:50051' or 'grpcs://weaviate.example.com:443')",
        default=None,
    )

    WEAVIATE_BATCH_SIZE: PositiveInt = Field(
        description="Number of objects to be processed in a single batch operation (default is 100)",
        default=100,
    )

    WEAVIATE_TOKENIZATION: str | None = Field(
        description="Tokenization for Weaviate (default is word)",
        default="word",
    )
