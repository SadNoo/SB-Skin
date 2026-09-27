"""Regression checks for upstream navigation entry points."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("integration", Path(__file__).with_name("apply_to_upstream.py"))
integration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(integration)


class IOSNavigationTests(unittest.TestCase):
    def test_remote_import_initializer_is_public_and_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "ApplicationLibrary/Views/Profile/NewProfileView.swift"
            source.parent.mkdir(parents=True)
            source.write_text('''public struct NewProfileView {
    public struct ImportRequest: Codable, Hashable, Identifiable {
        public var id: String { url }
        public let name: String
        public let url: String
    }
}
''')
            integration.patch_import_request(directory)
            first = source.read_text()
            self.assertIn("public init(name: String, url: String)", first)
            self.assertIn("self.name = name", first)
            integration.patch_import_request(directory)
            self.assertEqual(source.read_text(), first)

    def test_adaptive_ipad_layout_and_existing_install(self):
        for tab_body in ("TabView { Text(\"Home\") }", "SkinIntegrationRoot()"):
            with self.subTest(tab_body=tab_body), tempfile.TemporaryDirectory() as directory:
                source = Path(directory) / "SFI/MainView.swift"
                source.parent.mkdir()
                source.write_text('''struct MainView {
    private var tabViewContent: some View {
        BODY
    }
    private var rootContent: some View {
        if SidebarLayout.isEnabled(horizontalSizeClass) {
            adaptiveTabViewContent
        } else {
            tabViewContent
        }
    }
    private func openURL(url: URL) {
        upstreamOpen(url)
    }
}
'''.replace("BODY", tab_body))
                integration.patch_ios_main_view(directory)
                first = source.read_text()
                self.assertIn("private var rootContent: some View {\n        SkinIntegrationRoot()", first)
                self.assertNotIn("adaptiveTabViewContent", first)
                self.assertIn("upstreamOpen(url)", first)
                self.assertEqual(first.count("SkinIntegration.handle(url, environments: environments)"), 1)
                integration.patch_ios_main_view(directory)
                self.assertEqual(source.read_text(), first)


if __name__ == "__main__":
    unittest.main()
