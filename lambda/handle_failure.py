def handler(event, context):
    error_info = event.get("error", {})

    error_type = error_info.get("Error", "UnknownError")
    error_message = error_info.get("Cause", "No details available")

    result = {
        "status": "FAILED",
        "error_type": error_type,
        "error_message": error_message
    }

    # In a real system, this is where you would release any inventory
    # that was reserved earlier in the workflow, before the failure
    # happened - not implemented here, since this project is
    # educational and doesn't connect to a real inventory system.

    return result