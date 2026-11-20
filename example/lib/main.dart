// A short tour of animated_stickers: one sticker, a sticker driven by a
// StickerController, and a grid drawn through a StickerAtlasScope.
//
// The three stickers ship in assets/ (declared in pubspec.yaml): a VP9 WebM
// with alpha, an animated WebP and a GIF.
import 'package:animated_stickers/animated_stickers.dart';
import 'package:material_ui/material_ui.dart';

const _webm = StickerSource.asset('assets/vp9_alpha_512.webm');
const _webp = StickerSource.asset('assets/anim.webp');
const _gif = StickerSource.asset('assets/anim_disposal.gif');

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'animated_stickers',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _page = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('animated_stickers')),
    body: switch (_page) {
      0 => const QuickStartPage(),
      1 => const ControllerPage(),
      _ => const AtlasGridPage(),
    },
    bottomNavigationBar: NavigationBar(
      selectedIndex: _page,
      onDestinationSelected: (page) => setState(() => _page = page),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.play_circle), label: 'Sticker'),
        NavigationDestination(icon: Icon(Icons.tune), label: 'Controller'),
        NavigationDestination(icon: Icon(Icons.grid_view), label: 'Atlas'),
      ],
    ),
  );
}

/// Each format in a plain [Sticker]: it loops while it is on screen.
class QuickStartPage extends StatelessWidget {
  const QuickStartPage({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        Sticker(source: _webm, width: 160, height: 160),
        Sticker(source: _webp, width: 160, height: 160),
        Sticker(source: _gif, width: 160, height: 160),
      ],
    ),
  );
}

/// A non-looping sticker on a [StickerController], with an error builder.
class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key});

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> {
  final _controller = StickerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Sticker(
          source: _webm,
          width: 240,
          height: 240,
          controller: _controller,
          loop: false,
          placeholder: const Center(child: CircularProgressIndicator()),
          errorBuilder: (context, error, stackTrace) =>
              Center(child: Text('Can\'t play this sticker: $error')),
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filled(
                tooltip: _controller.isPlaying ? 'Pause' : 'Play',
                icon: Icon(
                  _controller.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: _controller.isPlaying
                    ? _controller.pause
                    : _controller.play,
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Restart',
                icon: const Icon(Icons.replay),
                onPressed: () => _controller.seekToFrame(0),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 300 stickers in a grid, drawn through a few shared atlas textures instead
/// of a texture each. Only the cells on screen hold an animation.
class AtlasGridPage extends StatelessWidget {
  const AtlasGridPage({super.key});

  static const _sources = [_webm, _webp, _gif];

  @override
  Widget build(BuildContext context) => StickerAtlasScope(
    child: GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 96,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: 300,
      itemBuilder: (context, i) =>
          Sticker(source: _sources[i % _sources.length]),
    ),
  );
}
