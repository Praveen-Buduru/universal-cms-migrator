package com.gmt.core.services;

import com.gmt.core.configurations.OpenApiConfig;
import org.osgi.service.component.annotations.Activate;
import org.osgi.service.component.annotations.Component;
import org.osgi.service.component.annotations.Modified;
import org.osgi.service.metatype.annotations.Designate;

@Component(service = OpenApiConfigurationService.class, immediate = true)
@Designate(ocd = OpenApiConfig.class)
public class OpenApiConfigurationService {

    private String endpoint;
    private String apiKey;

    @Activate
    @Modified
    protected void activate(OpenApiConfig config) {
        this.endpoint = config.endpoint();
        this.apiKey = config.apiKey();
    }

    public String getEndpoint() {
        return endpoint;
    }

    public String getApiKey() {
        return apiKey;
    }
}
