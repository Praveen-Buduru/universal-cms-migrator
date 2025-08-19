package com.gmt.core.servlets;

import com.day.cq.dam.api.AssetManager;
import org.apache.commons.lang3.StringEscapeUtils;
import org.apache.sling.api.SlingHttpServletRequest;
import org.apache.sling.api.SlingHttpServletResponse;
import org.apache.sling.api.resource.ResourceResolver;
import org.apache.sling.api.servlets.SlingAllMethodsServlet;
import org.osgi.framework.Constants;
import org.osgi.service.component.annotations.Component;

import javax.jcr.Binary;
import javax.jcr.RepositoryException;
import javax.jcr.Session;
import javax.servlet.Servlet;
import javax.servlet.ServletException;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Component(
        service = Servlet.class,
        property = {
                Constants.SERVICE_DESCRIPTION + "=Fetch Images from Webpage and Upload to DAM",
                "sling.servlet.methods=GET",
                "sling.servlet.paths=/bin/fetchImagesToDam"
        }
)
public class FetchImagesToDamServlet extends SlingAllMethodsServlet {

    @Override
    protected void doGet(SlingHttpServletRequest request, SlingHttpServletResponse response)
            throws ServletException, IOException {

        String pageUrl = request.getParameter("pageUrl");
        String damFolderPath = request.getParameter("damFolderPath");

        if (pageUrl == null || damFolderPath == null) {
            response.setStatus(400);
            response.getWriter().write("Missing parameters: pageUrl, damFolderPath");
            return;
        }


        try (ResourceResolver resolver = request.getResourceResolver()) {
            Session session = resolver.adaptTo(Session.class);
            AssetManager assetManager = resolver.adaptTo(AssetManager.class);

            if (session == null || assetManager == null) {
                response.getWriter().write("Could not adapt to Session or AssetManager");
                return;
            }

            // Fetch HTML
            String html = fetchHtml(pageUrl);

            // Parse image URLs
            List<String> imageUrls = extractImageUrls(html);

            response.getWriter().write("Found " + imageUrls.size() + " image(s):\n");

            int count = 0;
            for (String imgUrl : imageUrls) {
                try (InputStream is = fetchImageStream(imgUrl, pageUrl)) {
                    String fileName = imgUrl.substring(imgUrl.lastIndexOf("/") + 1);
                    String damPath = damFolderPath + "/" + fileName;

                    String mimeType = detectMimeType(fileName);
                    Binary binary = session.getValueFactory().createBinary(is);

                    assetManager.createOrUpdateAsset(damPath, binary, mimeType, true);
                    response.getWriter().write("Uploaded: " + damPath + "\n");
                    count++;
                } catch (Exception e) {
                    response.getWriter().write("Failed to upload " + imgUrl + " : " + e.getMessage() + "\n");
                }
            }

            session.save();
            response.getWriter().write("Uploaded " + count + " image(s) to DAM.\n");

        } catch (RepositoryException e) {
            throw new ServletException(e);
        }
    }

    private String fetchHtml(String pageUrl) throws IOException {
        HttpURLConnection conn = (HttpURLConnection) new URL(pageUrl).openConnection();
        conn.setRequestProperty("User-Agent", "Mozilla/5.0");
        conn.setRequestProperty("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
        conn.setRequestProperty("Accept-Language", "en-US,en;q=0.9");
        conn.setRequestProperty("Cache-Control", "no-cache");
        conn.setRequestProperty("Pragma", "no-cache");
        conn.setInstanceFollowRedirects(true);
        try (InputStream is = conn.getInputStream()) {
            return new String(is.readAllBytes(), StandardCharsets.UTF_8);
        }
    }

    private List<String> extractImageUrls(String html) {
        List<String> imageUrls = new ArrayList<>();
        Pattern pattern = Pattern.compile("<img[^>]+(?:src|data-src|data-srcset|data-lazy-src|data-lazy-srcset|srcset)=[\"']([^\"']+)[\"']", Pattern.CASE_INSENSITIVE);
        Matcher matcher = pattern.matcher(html);

        while (matcher.find()) {
            String imgUrl = StringEscapeUtils.unescapeHtml4(matcher.group(1));

            if (imgUrl.contains(",")) {
                imgUrl = imgUrl.split(",")[0].trim().split(" ")[0];
            }

            if (!imgUrl.startsWith("http")) {
                imgUrl = "https://www.nokia.com" + (imgUrl.startsWith("/") ? "" : "/") + imgUrl;
            }

            imgUrl = imgUrl.replaceAll("\\?.*$", "");

            if (!imgUrl.toLowerCase().endsWith(".webp")) {
                imgUrl = imgUrl.replaceFirst("/styles/[^/]+/public/", "/");
            }

            if (!imageUrls.contains(imgUrl)) {
                imageUrls.add(imgUrl);
            }
        }
        return imageUrls;
    }

    private InputStream fetchImageStream(String imgUrl, String referer) throws IOException {
        HttpURLConnection conn = (HttpURLConnection) new URL(imgUrl).openConnection();
        conn.setRequestProperty("User-Agent", "Mozilla/5.0");
        conn.setRequestProperty("Accept", "image/avif,image/webp,image/*,*/*;q=0.8");
        conn.setRequestProperty("Referer", referer);
        conn.setRequestProperty("Cache-Control", "no-cache");
        conn.setRequestProperty("Pragma", "no-cache");
        conn.setInstanceFollowRedirects(true);
        return conn.getInputStream();
    }

    private String detectMimeType(String fileName) {
        String lower = fileName.toLowerCase();
        if (lower.endsWith(".webp")) return "image/webp";
        if (lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.contains(".jpg.")) return "image/jpeg";
        if (lower.endsWith(".png")) return "image/png";
        if (lower.endsWith(".gif")) return "image/gif";
        return "application/octet-stream";
    }
}
