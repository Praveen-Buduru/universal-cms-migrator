package com.gmt.core.servlets;

import com.day.cq.commons.jcr.JcrConstants;
import org.apache.commons.io.FilenameUtils;
import org.apache.sling.api.SlingHttpServletRequest;
import org.apache.sling.api.SlingHttpServletResponse;
import org.apache.sling.api.resource.ResourceResolver;
import org.apache.sling.api.servlets.SlingAllMethodsServlet;
import org.osgi.service.component.annotations.Component;
import org.osgi.framework.Constants;

import javax.jcr.Node;
import javax.jcr.Session;
import javax.servlet.Servlet;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Calendar;

@Component(
        service = Servlet.class,
        property = {
                Constants.SERVICE_DESCRIPTION + "=Download External Image to AEM DAM (No AssetManager)",
                "sling.servlet.methods=POST",
                "sling.servlet.paths=/bin/importExternalImage"
        }
)
public class ImportExternalImageServlet extends SlingAllMethodsServlet {

    private static final String DAM_FOLDER = "/content/dam/universal-migration-tool/images";

    @Override
    protected void doPost(SlingHttpServletRequest request, SlingHttpServletResponse response) {
        String imageUrl = request.getParameter("url");

        if (imageUrl == null || imageUrl.isEmpty()) {
            sendError(response, "Missing 'url' parameter");
            return;
        }

        String fileName = FilenameUtils.getName(imageUrl);
        if (fileName == null || fileName.isEmpty()) {
            sendError(response, "Unable to extract file name from URL");
            return;
        }

        try {
            ResourceResolver resolver = request.getResourceResolver();
            Session session = resolver.adaptTo(Session.class);

            // Ensure DAM folder exists
            Node damFolderNode = getOrCreateFolder(session, DAM_FOLDER);

            // Open connection with proper headers
            URL url = new URL(imageUrl);
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            connection.setRequestProperty("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)");
            connection.setRequestProperty("Referer", url.getProtocol() + "://" + url.getHost() + "/");
            connection.setRequestProperty("Accept", "image/webp,image/apng,image/*,*/*;q=0.8");
            connection.connect();

            String mimeType = connection.getContentType();
            if (mimeType == null || mimeType.isEmpty()) {
                mimeType = "image/jpeg"; // default fallback
            }

            try (InputStream is = connection.getInputStream()) {
                Node assetNode = damFolderNode.addNode(fileName, "dam:Asset");

                Node contentNode = assetNode.addNode(JcrConstants.JCR_CONTENT, "dam:AssetContent");
                contentNode.setProperty(JcrConstants.JCR_MIMETYPE, mimeType);
                contentNode.setProperty(JcrConstants.JCR_LASTMODIFIED, Calendar.getInstance());

                // Create renditions/original path properly
                Node renditionsNode = contentNode.addNode("renditions", "sling:Folder");
                Node originalNode = renditionsNode.addNode("original", "nt:file");
                Node originalContentNode = originalNode.addNode(JcrConstants.JCR_CONTENT, "nt:resource");

                originalContentNode.setProperty(JcrConstants.JCR_MIMETYPE, mimeType);
                originalContentNode.setProperty(JcrConstants.JCR_DATA, session.getValueFactory().createBinary(is));
                originalContentNode.setProperty(JcrConstants.JCR_LASTMODIFIED, Calendar.getInstance());

                session.save();
            }


            response.getWriter().write("✅ Image imported successfully at: " + DAM_FOLDER + "/" + fileName);

        } catch (Exception e) {
            e.printStackTrace();
            sendError(response, "Error importing image: " + e.getMessage());
        }
    }

    private Node getOrCreateFolder(Session session, String path) throws Exception {
        String[] parts = path.substring(1).split("/");
        Node currentNode = session.getRootNode();
        for (String part : parts) {
            if (!currentNode.hasNode(part)) {
                currentNode = currentNode.addNode(part, "sling:Folder");
            } else {
                currentNode = currentNode.getNode(part);
            }
        }
        return currentNode;
    }

    private void sendError(SlingHttpServletResponse response, String message) {
        try {
            response.setStatus(400);
            response.getWriter().write("❌ " + message);
        } catch (Exception ignored) {}
    }
}
