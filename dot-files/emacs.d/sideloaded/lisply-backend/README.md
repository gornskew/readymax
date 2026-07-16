# Emacs Lisply Backend - HTTP API for Emacs Lisp Evaluation

Emacs Lisply Backend provides a simple HTTP API that exposes Emacs Lisp evaluation capabilities. It allows external clients to interact with Emacs through standard HTTP requests. This project focuses solely on providing the Emacs backend service that can be containerized and deployed independently.


## Overview

GNU Emacs is a powerful text editor that can run as a daemon (server) and contains an interpreter for the Emacs Lisp language. This implementation exposes Emacs functionality via a simple HTTP API, allowing any client to:

1. Evaluate Emacs Lisp expressions
2. Access and manipulate buffers
3. Read and write files
4. Execute Emacs commands programmatically

This enables external tools, scripts, or services to harness the power of Emacs Lisp for text processing, file manipulation, and other operations in a containerized environment.

## Key Features

- **HTTP Server**: Exposes Emacs functionality through a simple HTTP API
- **JSON Responses**: Returns data in standardized JSON format
- **Lisp Evaluation**: Evaluate arbitrary Emacs Lisp code securely
- **Buffer Access**: List and manipulate Emacs buffers
- **File Operations**: Read from and write to files
- **Containerized**: Runs in an isolated Docker container

## Security Considerations

Because this implementation allows arbitrary Emacs Lisp code to be
evaluated against the running Emacs daemon, best practices are:

- Allow an LLM to connect only to a containerized version of emacs
  (handled automatically by default by [lisply-mcp
  project](https://github.com/gornskew/lisply-mcp);
- Make sure not to mount any valuable directories to that container;
- Take steps to [limit RAM and CPU
  usage](https://docs.docker.com/engine/containers/resource_constraints/)
  of the container ([lisply-mcp
  project](https://github.com/gornskew/lisply-mcp) aims to support
  these options as pass-through to the automated container startup).


## Installation

### Direct Installation in Emacs (use with caution if not using a container)

> **Warning:** running this in your host Emacs lets any MCP client evaluate
> arbitrary Emacs Lisp — i.e. run arbitrary code on your machine. Prefer the
> container path unless you understand the exposure.

1. Install the required package:
   - simple-httpd: `M-x package-install RET simple-httpd RET`

2. Add the `source/` directory to your `load-path`, then load the two
   entry-point files:
   ```elisp
   (add-to-list 'load-path "/path/to/lisply-backend/source/")
   (load "http-setup")
   (load "endpoints")
   ```

3. Start the server:
   ```elisp
   (emacs-lisply-start-server)   ; binds `httpd-host':`emacs-lisply-port' (default 7080)
   ```

If you are using skewed-emacs you do not need to do any of this by hand —
see `etc/lisply-config.el` and `docs/HOST_EMACS_MCP.md`, which wrap these
steps behind `M-x lisply-enable-host-server` and a security confirmation.

### Docker Container

Build and run the provided Docker container:

```bash
# Build the container
./docker/build.sh

# Run the container
./docker/run-container.sh
```

## API Usage

The Lisply backend exposes a simple HTTP API that allows clients to evaluate Emacs Lisp code and interact with Emacs. Clients can directly connect to the server on port 7080 (internal container port) or 7081 (default mapped host port).

### Example API Usage

Here's how to interact with the Lisply backend using curl:

```bash
# Check if the server is running
curl http://localhost:7081/lisply/ping-lisp

# Evaluate a simple expression
curl -X POST http://localhost:7081/lisply/lisp-eval \
  -H "Content-Type: application/json" \
  -d '{"code": "(+ 1 2 3)"}'

# Evaluate a simple expression with side-effect printing to *standard-output*
curl -X POST http://localhost:7081/lisply/lisp-eval \
  -H "Content-Type: application/json" \
  -d '{"code": "(let ((result (+ 1 2 3))) (format t "Result is: ~a~%" result) result)"}'

```

### Integration with Other Tools

This backend can be integrated with any client that can make HTTP requests. It provides the foundation for tools that need to interact with Emacs programmatically, including:

- LLM (Large Language Model) tools
- Development environments
- CI/CD pipelines
- Custom scripts and utilities

When integrating with tool frameworks that support the Model Context Protocol, you'll need to point them to this server's endpoint.

## MCP Tools

The Emacs Lisply implementation provides two tools for Claude interaction:

- `ping_lisp` - Check if the Emacs server is accessible
- `lisp_eval` - Evaluate Emacs Lisp code in the Emacs environment

Note: A third tool, `http_request`, is implemented in the Lisply MCP wrapper middleware and not directly in this backend. This tool allows Claude to make HTTP requests to any endpoint on the Emacs server.

## API Endpoints

- `/lisply/ping-lisp` - Check if the server is available
- `/lisply/lisp-eval` - Evaluate Emacs Lisp code
- `/lisply/tools/list` - List available MCP tools
- `/lisply/resources/list` - List available resources (currently empty)
- `/lisply/prompts/list` - List available prompts (currently empty)

These endpoint paths are configurable via variables in the backend implementation to allow alignment with the MCP wrapper configuration.

## Development

### Project Structure

- `source/http-setup.el` - HTTP server configuration
- `source/endpoints.el` - MCP endpoint definitions

### Building the Container

The container build process:
1. Copies the entire skewed-emacs repository into the container
2. Runs the `./setup` script to configure the Emacs environment
3. Installs required packages using the on-demand installation mechanism in init.el
4. Configures the Lisply backend

```bash
./docker/build.sh -t your-tag -n your-image-name
```

Now you can configure your mcp-wrapper.js to use this new container
image, or first test it by running manually:

```bash
./docker/run-container.sh -i your-image-name:your-tag -p 7081 -m /path/to/your/projects
```

Note: By default, the container exposes port 7080 internally but maps
to port 7081 on the host to avoid potential conflicts.

## Error Handling

The Lisply backend provides structured error handling via HTTP responses:

- Success responses include a `success` field set to `true`, along with `result` and `stdout` fields
- Error responses set the `success` field to `false` and include an `error` field with the error message

Unlike Common Lisp implementations, Emacs Lisp doesn't have a built-in interactive debugger that can be exposed via stdio. The error handling is entirely through the structured HTTP responses.

## License

This project is licensed under the GNU Affero General Public License
v3.0 (AGPL-3.0), which is compatible with GNU Emacs' GPL-3.0
license. The AGPL-3.0 provides all the protections of GPL-3.0 plus an
additional provision to ensure that modifications to the software when
used over a network are also made available to users.

## Acknowledgments

Thank you to emacs developers and the MCP community.
