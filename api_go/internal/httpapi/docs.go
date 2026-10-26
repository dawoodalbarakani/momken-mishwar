package httpapi

import (
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
)

var openAPIDoc []byte

func init() {
	// Resolve the OpenAPI spec relative to the module root (api_go/).
	// Candidates: internal/httpapi/docs/openapi.yaml (package-local) and
	// ../docs/openapi.yaml (module root). Try both.
	candidates := []string{
		filepath.Join("internal", "httpapi", "docs", "openapi.yaml"),
		filepath.Join("docs", "openapi.yaml"),
		"openapi.yaml",
	}
	for _, c := range candidates {
		if b, err := os.ReadFile(c); err == nil {
			openAPIDoc = b
			return
		}
	}
	// Fall back to a minimal inline spec so docs endpoints still work.
	openAPIDoc = []byte("openapi: 3.0.3\ninfo:\n  title: Mishwar API\n  version: v1\npaths: {}\n")
}

// docsUI returns an HTML page that loads Swagger UI from a CDN and points it
// at the OpenAPI spec served by this server.
func swaggerUIHTML(specURL string) string {
	return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Mishwar API — Swagger UI</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5.17.14/swagger-ui.css" crossorigin="anonymous"/>
  <style>html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; } body { margin: 0; background: #fafafa; }</style>
</head>
<body>
<div id="swagger-ui"></div>
<script src="https://unpkg.com/swagger-ui-dist@5.17.14/swagger-ui-bundle.js" crossorigin="anonymous"></script>
<script>
window.onload = function() {
  const ui = SwaggerUIBundle({
    url: '` + specURL + `',
    dom_id: '#swagger-ui',
    deepLinking: true,
    presets: [SwaggerUIBundle.presets.apis],
    layout: 'StandaloneLayout',
    validatorUrl: null,
    persistAuthorization: true,
    displayRequestDuration: true,
    filter: true,
  });
  window.ui = ui;
};
</script>
</body>
</html>`
}

// redocUI returns an HTML page that loads ReDoc from a CDN and points it at the
// OpenAPI spec served by this server.
func redocUIHTML(specURL string) string {
	return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Mishwar API — ReDoc</title>
  <style>body { margin: 0; padding: 0; } #redoc { display: block; height: 100vh; }</style>
</head>
<body>
<redoc spec-url='` + specURL + `'></redoc>
<script src="https://unpkg.com/redoc@2.1.0/bundles/redoc.standalone.js"></script>
</body>
</html>`
}

// RegisterDocs mounts the OpenAPI spec endpoint plus Swagger UI and ReDoc on
// the given mux. It is intentionally unauthenticated so API clients and docs
// tooling can fetch the contract without a token.
func RegisterDocs(mux *http.ServeMux, logger *slog.Logger) {
	specURL := "/api/v1/openapi.yaml"

	mux.HandleFunc("GET /api/v1/openapi.yaml", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/yaml")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		_, _ = w.Write(openAPIDoc)
	})

	mux.HandleFunc("GET /docs/swagger", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		_, _ = w.Write([]byte(swaggerUIHTML(specURL)))
	})

	mux.HandleFunc("GET /docs/redoc", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		_, _ = w.Write([]byte(redocUIHTML(specURL)))
	})

	// Convenience redirects.
	mux.HandleFunc("GET /docs", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "/docs/swagger", http.StatusFound)
	})
	mux.HandleFunc("GET /openapi.yaml", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, specURL, http.StatusFound)
	})
}
