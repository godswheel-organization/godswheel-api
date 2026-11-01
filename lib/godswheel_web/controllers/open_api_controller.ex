defmodule GodsWheelWeb.OpenApiController do
  use GodsWheelWeb, :controller

  def spec(conn, _params) do
    json(conn, specification())
  end

  def swagger_ui(conn, _params) do
    html = """
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8">
        <title>Godswheel API - Swagger UI</title>
        <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
      </head>
      <body>
        <div id="swagger-ui"></div>
        <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
        <script>
          window.onload = () => {
            SwaggerUIBundle({
              url: "/api/v1/openapi.json",
              dom_id: "#swagger-ui",
              deepLinking: true
            });
          };
        </script>
      </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(:ok, html)
  end

  defp specification do
    %{
      openapi: "3.1.0",
      info: %{
        title: "Godswheel API",
        version: "0.1.0",
        description: "HTTP API for the Godswheel platform."
      },
      servers: [%{url: "/"}],
      tags: [
        %{name: "Health", description: "Service health checks"},
        %{name: "Authentication", description: "Account registration and authentication"},
        %{name: "Sermons", description: "Public sermon discovery and catalogue"},
        %{name: "Categories", description: "Public sermon categories"},
        %{name: "Speakers", description: "Public sermon speakers"}
      ],
      paths: %{
        "/api/v1/sermons" => %{
          get: catalogue_operation(
            "Sermons",
            "List sermons",
            "Returns published sermons with optional title/description search, filters, sorting and pagination. Omit search_in[] to search both title and description; provide title and/or description to restrict the search fields.",
            ["search", "search_in[]", "category_id", "speaker_id", "scripture", "language", "sort", "page", "limit"],
            "SermonListResponse"
          )
        },
        "/api/v1/sermons/{id}" => %{
          get: %{
            tags: ["Sermons"],
            summary: "Get sermon",
            parameters: [%{name: "id", in: "path", required: true, schema: %{type: "string", format: "uuid"}}],
            responses: %{
              "200" => response("Published sermon details.", "SermonResponse"),
              "404" => response("Sermon not found.", "ErrorResponse")
            }
          }
        },
        "/api/v1/categories" => %{
          get: catalogue_operation("Categories", "List categories", "Searches categories by name and returns paginated results.", ["search", "page", "limit"], "CategoryListResponse")
        },
        "/api/v1/speakers" => %{
          get: catalogue_operation("Speakers", "List speakers", "Searches speakers by name and returns paginated results.", ["search", "page", "limit"], "SpeakerListResponse")
        },
        "/api/v1/health" => %{
          get: %{
            tags: ["Health"],
            summary: "Check API health",
            description: "Returns the basic application health status. This endpoint does not expose dependency or infrastructure details.",
            responses: %{
              "200" => response("The API is healthy.", "HealthResponse")
            }
          }
        },
        "/api/v1/auth/signup" => %{
          post: operation(
            "Authentication",
            "Register an account",
            "Creates an unverified account and sends an email verification link. No access token is issued until the email address is verified.",
            "SignupRequest",
            %{
              "201" => response("Account created; verification email sent.", "SignupResponse"),
              "422" => response("Validation errors.", "ValidationError")
            }
          )
        },
        "/api/v1/auth/login" => %{
          post: operation(
            "Authentication",
            "Log in",
            "Authenticates with an email address. Unverified accounts cannot log in.",
            "LoginRequest",
            %{
              "200" => response("Authenticated.", "SessionResponse"),
              "401" => response("Invalid credentials.", "ErrorResponse"),
              "403" => response("Email address has not been verified.", "ErrorResponse"),
              "422" => response("Missing or invalid request fields.", "ErrorResponse")
            }
          )
        },
        "/api/v1/auth/verify-email" => %{
          post: operation(
            "Authentication",
            "Verify email address",
            "Consumes a single-use verification token and returns an access token after successful verification.",
            "TokenRequest",
            %{
              "200" => response("Email verified and authenticated.", "SessionResponse"),
              "422" => response("Token is invalid, expired, or missing.", "ErrorResponse")
            }
          )
        },
        "/api/v1/auth/refresh" => %{
          post: %{
            tags: ["Authentication"],
            summary: "Refresh access token",
            description: "Uses the HttpOnly refresh-token cookie to rotate the session refresh token and issue a new one-hour access token. The browser must send credentials.",
            security: [%{RefreshCookie: []}],
            responses: %{
              "200" => response("Access token refreshed; refresh cookie rotated.", "RefreshResponse"),
              "401" => response("Refresh session is invalid, expired, or revoked.", "ErrorResponse"),
              "403" => response("Request origin is not allowed.", "ErrorResponse")
            }
          }
        },
        "/api/v1/auth/logout" => %{
          post: %{
            tags: ["Authentication"],
            summary: "Log out current session",
            security: [%{BearerAuth: []}],
            responses: %{
              "200" => response("Current session revoked and refresh cookie cleared.", "MessageResponse"),
              "401" => response("Authentication required.", "ErrorResponse")
            }
          }
        },
        "/api/v1/auth/logout-all" => %{
          post: %{
            tags: ["Authentication"],
            summary: "Log out all sessions",
            security: [%{BearerAuth: []}],
            responses: %{
              "200" => response("All user sessions revoked.", "MessageResponse"),
              "401" => response("Authentication required.", "ErrorResponse")
            }
          }
        },
        "/api/v1/auth/resend-verification" => %{
          post: operation(
            "Authentication",
            "Resend verification email",
            "Sends a new verification link when an unverified account exists. The response is generic to avoid account enumeration.",
            "EmailRequest",
            %{
              "200" => response("Generic confirmation.", "MessageResponse"),
              "422" => response("Email is missing.", "ErrorResponse")
            }
          )
        },
        "/api/v1/auth/forgot-password" => %{
          post: operation(
            "Authentication",
            "Request password reset",
            "Sends password-reset instructions to a verified account, if one exists.",
            "EmailRequest",
            %{
              "200" => response("Generic confirmation.", "MessageResponse"),
              "422" => response("Email is missing.", "ErrorResponse")
            }
          )
        },
        "/api/v1/auth/reset-password" => %{
          post: operation(
            "Authentication",
            "Reset password",
            "Consumes a single-use password-reset token and updates the account password.",
            "ResetPasswordRequest",
            %{
              "200" => response("Password reset successfully.", "MessageResponse"),
              "422" => response("Invalid, expired token or invalid password.", "ErrorResponse")
            }
          )
        },
        "/api/v1/auth/me" => %{
          get: %{
            tags: ["Authentication"],
            summary: "Get current user",
            description: "Returns the authenticated user's public profile.",
            security: [%{BearerAuth: []}],
            responses: %{
              "200" => response("Current user.", "UserResponse"),
              "401" => response("Authentication required.", "ErrorResponse")
            }
          }
        }
      },
      components: %{
        securitySchemes: %{
          RefreshCookie: %{
            type: "apiKey",
            in: "cookie",
            name: "godswheel_refresh"
          },
          BearerAuth: %{
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT"
          }
        },
        schemas: %{
          PaginationMeta: object_schema(%{
            page: %{type: "integer"},
            limit: %{type: "integer"},
            totalEntries: %{type: "integer"},
            totalPages: %{type: "integer"},
            hasNextPage: %{type: "boolean"},
            hasPrevPage: %{type: "boolean"}
          }, ["page", "limit", "totalEntries", "totalPages", "hasNextPage", "hasPrevPage"]),
          Sermon: object_schema(%{
            id: %{type: "string", format: "uuid"},
            title: string_schema("Sermon title"),
            slug: string_schema("Sermon slug"),
            description: string_schema("Sermon description"),
            audioUrl: string_schema("Audio resource URL"),
            thumbnailUrl: string_schema("Thumbnail URL"),
            scriptureReference: string_schema("Scripture reference"),
            durationSeconds: %{type: ["integer", "null"]},
            language: string_schema("Language"),
            publishedAt: %{type: "string", format: "date-time"},
            speaker: ref_schema("Speaker"),
            categories: %{type: "array", items: ref_schema("Category")}
          }, ["id", "title", "slug", "audioUrl", "speaker", "categories"]),
          Category: object_schema(%{
            id: %{type: "string", format: "uuid"},
            name: string_schema("Category name"),
            slug: string_schema("Category slug"),
            description: string_schema("Category description")
          }, ["id", "name", "slug"]),
          Speaker: object_schema(%{
            id: %{type: "string", format: "uuid"},
            name: string_schema("Speaker name"),
            bio: string_schema("Speaker biography"),
            imageUrl: string_schema("Speaker image URL")
          }, ["id", "name"]),
          SermonListResponse: object_schema(%{
            success: %{type: "boolean", enum: [true]},
            data: %{type: "array", items: ref_schema("Sermon")},
            meta: ref_schema("PaginationMeta")
          }, ["success", "data", "meta"]),
          SermonResponse: object_schema(%{
            success: %{type: "boolean", enum: [true]},
            data: ref_schema("Sermon")
          }, ["success", "data"]),
          CategoryListResponse: object_schema(%{
            success: %{type: "boolean", enum: [true]},
            data: %{type: "array", items: ref_schema("Category")},
            meta: ref_schema("PaginationMeta")
          }, ["success", "data", "meta"]),
          SpeakerListResponse: object_schema(%{
            success: %{type: "boolean", enum: [true]},
            data: %{type: "array", items: ref_schema("Speaker")},
            meta: ref_schema("PaginationMeta")
          }, ["success", "data", "meta"]),
          HealthResponse: object_schema(%{
            success: %{type: "boolean", enum: [true]},
            data: object_schema(%{
              status: %{type: "string", enum: ["ok"]}
            }, ["status"])
          }, ["success", "data"]),
          SignupRequest: object_schema(
            %{
              full_name: string_schema("User's full name", minLength: 2, maxLength: 120),
              email: string_schema("Email address", format: "email", maxLength: 254),
                            password: string_schema("Password; 8 to 72 characters", minLength: 8, maxLength: 72)
            },
            ["full_name", "email", "password"]
          ),
          SignupResponse: object_schema(%{
            success: %{type: "boolean", enum: [true]},
            data: object_schema(%{
              message: string_schema("Registration confirmation message"),
              user: ref_schema("PublicUser")
            }, ["message", "user"])
          }, ["success", "data"]),
          LoginRequest: object_schema(%{
            email: string_schema("Email address", format: "email"),
            password: string_schema("Account password")
          }, ["email", "password"]),
          EmailRequest: object_schema(%{
            email: string_schema("Email address", format: "email")
          }, ["email"]),
          TokenRequest: object_schema(%{
            token: string_schema("Single-use email verification token")
          }, ["token"]),
          ResetPasswordRequest: object_schema(%{
            token: string_schema("Single-use password-reset token"),
            password: string_schema("New password; 8 to 72 characters", minLength: 8, maxLength: 72)
          }, ["token", "password"]),
          SessionResponse: object_schema(%{
            success: %{type: "boolean", enum: [true]},
            data: object_schema(%{
              user: ref_schema("PublicUser"),
              accessToken: string_schema("Signed JWT access token"),
              tokenType: %{type: "string", enum: ["Bearer"]},
              expiresIn: %{type: "integer", description: "Access token lifetime in seconds"},
              expiresAt: %{type: "string", format: "date-time"}
            }, ["user", "accessToken", "tokenType", "expiresIn", "expiresAt"])
          }, ["success", "data"]),
          RefreshResponse: object_schema(%{
            success: %{type: "boolean", enum: [true]},
            data: object_schema(%{
              accessToken: string_schema("New signed JWT access token"),
              tokenType: %{type: "string", enum: ["Bearer"]},
              expiresIn: %{type: "integer"},
              expiresAt: %{type: "string", format: "date-time"}
            }, ["accessToken", "tokenType", "expiresIn", "expiresAt"])
          }, ["success", "data"]),
          UserResponse: object_schema(%{
            success: %{type: "boolean", enum: [true]},
            data: ref_schema("PublicUser")
          }, ["success", "data"]),
          PublicUser: object_schema(%{
            id: %{type: "string", format: "uuid"},
            fullName: string_schema("User's full name"),
            email: string_schema("Email address", format: "email"),
            emailVerified: %{type: "boolean"}
          }, ["id", "fullName", "email", "emailVerified"]),
          MessageResponse: object_schema(%{
            success: %{type: "boolean", enum: [true]},
            data: object_schema(%{
              message: string_schema("Human-readable result message")
            }, ["message"])
          }, ["success", "data"]),
          ErrorResponse: object_schema(%{
            success: %{type: "boolean", enum: [false]},
            error: object_schema(%{
              code: %{type: "string"},
              message: string_schema("Human-readable error message"),
              details: %{type: ["object", "null"], additionalProperties: true}
            }, ["code", "message", "details"])
          }, ["success", "error"]),
          ValidationError: ref_schema("ErrorResponse")
        }
      }
    }
  end


defp catalogue_operation(tag, summary, description, parameter_names, response_schema) do
  %{
    tags: [tag],
    summary: summary,
    description: description,
    parameters:
      Enum.map(parameter_names, fn name ->
        %{
          name: name,
          in: "query",
          required: false,
          description: parameter_description(name),
          schema:
            cond do
              name == "page" ->
                %{type: "integer", minimum: 1, default: 1}

              name == "limit" ->
                %{type: "integer", minimum: 1, maximum: 100, default: 20}

              name == "search_in[]" ->
                %{
                  type: "array",
                  items: %{type: "string", enum: ["title", "description"]}
                }

              name == "sort" ->
                %{
                  type: "string",
                  enum: ["newest", "oldest"],
                  default: "newest"
                }

              true ->
                %{type: "string"}
            end,
          style: if(name == "search_in[]", do: "form", else: nil),
          explode: if(name == "search_in[]", do: true, else: nil)
        }
      end),
    responses: %{
      "200" => response("Paginated catalogue results.", response_schema),
      "422" => response("Invalid query parameters.", "ErrorResponse")
    }
  }
end

defp parameter_description("sort") do
  "Controls sermon ordering. newest: most recently published first (default). oldest: earliest published first."
end

defp parameter_description("search_in[]") do
  "Fields to search. Accepts title and/or description. When omitted, both fields are searched."
end

defp parameter_description(_name), do: nil


  defp operation(tag, summary, description, request_schema, responses) do
    %{
      tags: [tag],
      summary: summary,
      description: description,
      requestBody: %{
        required: true,
        content: %{
          "application/json" => %{
            schema: ref_schema(request_schema)
          }
        }
      },
      responses: responses
    }
  end

  defp response(description, schema) do
    %{
      description: description,
      content: %{
        "application/json" => %{
          schema: ref_schema(schema)
        }
      }
    }
  end

  defp object_schema(properties, required) do
    %{
      type: "object",
      properties: properties,
      required: required,
      additionalProperties: false
    }
  end

  defp string_schema(description, opts \\ []) do
    Map.merge(
      %{type: "string", description: description},
      Map.new(opts)
    )
  end

  defp ref_schema(name) do
    %{"$ref" => "#/components/schemas/#{name}"}
  end
end
