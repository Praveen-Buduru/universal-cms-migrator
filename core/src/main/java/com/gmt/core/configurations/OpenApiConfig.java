package com.gmt.core.configurations;

import org.osgi.service.metatype.annotations.AttributeDefinition;
import org.osgi.service.metatype.annotations.ObjectClassDefinition;

@ObjectClassDefinition(
        name = "OpenAPI Configuration",
        description = "Configuration to store OpenAPI endpoint and API key"
)
public @interface OpenApiConfig {

    @AttributeDefinition(
            name = "OpenAPI Endpoint",
            description = "The base URL of the OpenAPI endpoint"
    )
    String endpoint() default "";

    @AttributeDefinition(
            name = "API Key",
            description = "The API key used to authenticate with the OpenAPI"
    )
    String apiKey() default "";
}