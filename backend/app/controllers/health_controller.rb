def root
  render json: {
    service: "Reading Notes Backend API",
    status: "ok",
    health: "/healthz"
  }
end