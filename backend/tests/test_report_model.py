import pytest
from pydantic import ValidationError

from app.models.report_model import VibeReportCreate


def valid_report_data():
    return {
        "venue_id": "venue_123",
        "venue_name": "Test Lounge",
        "crowd_level": "Busy",
        "safety_level": "Safe",
        "music_type": "Amapiano",
        "queue_length": "Short",
        "yiyo_status": "Yes definitely",
        "parking_availability": "Available",
        "parking_safety": "Safe",
        "parking_note": "Guarded parking",
        "comment": "Good energy",
        "reported_at": "2026-09-17T18:00:00Z",
    }


def test_valid_report_is_accepted():
    report = VibeReportCreate(**valid_report_data())

    assert report.crowd_level == "Busy"
    assert report.safety_level == "Safe"
    assert report.yiyo_status == "Yes definitely"


def test_invalid_crowd_level_is_rejected():
    data = valid_report_data()
    data["crowd_level"] = "Extremely bananas"

    with pytest.raises(ValidationError):
        VibeReportCreate(**data)


def test_invalid_safety_level_is_rejected():
    data = valid_report_data()
    data["safety_level"] = "Perfectly safe forever"

    with pytest.raises(ValidationError):
        VibeReportCreate(**data)


def test_invalid_yiyo_status_is_rejected():
    data = valid_report_data()
    data["yiyo_status"] = "Maybe probably"

    with pytest.raises(ValidationError):
        VibeReportCreate(**data)


def test_comment_length_is_limited():
    data = valid_report_data()
    data["comment"] = "x" * 501

    with pytest.raises(ValidationError):
        VibeReportCreate(**data)


def test_unknown_fields_are_rejected():
    data = valid_report_data()
    data["made_up_field"] = "hello"

    with pytest.raises(ValidationError):
        VibeReportCreate(**data)


def test_string_fields_strip_outer_whitespace():
    data = valid_report_data()
    data["venue_name"] = "  Test Lounge  "
    data["comment"] = "  Good energy  "

    report = VibeReportCreate(**data)

    assert report.venue_name == "Test Lounge"
    assert report.comment == "Good energy"