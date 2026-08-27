import {
  Request,
  Response,
  NextFunction,
} from "express";

export function errorHandler(
  error: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction
) {
  console.error(error);

  if (
    error &&
    typeof error === "object" &&
    "statusCode" in error
  ) {
    const httpError =
      error as {
        statusCode: number;
        message: string;
      };

    return res
      .status(httpError.statusCode)
      .json({
        error: httpError.message,
      });
  }

  return res.status(500).json({
    error:
      "Error interno del servidor",
  });
}