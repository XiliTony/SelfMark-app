from selfmark_agent import __version__
from selfmark_agent.settings import settings


def test_workspace_package_imports_without_external_services():
    assert __version__ == "0.1.0"
    assert settings.api_base_url
