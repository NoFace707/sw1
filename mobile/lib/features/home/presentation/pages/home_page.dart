import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../auth/data/auth_service.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../viewer/data/viewer_repository.dart';
import '../../../viewer/domain/viewer_models.dart';
import '../../../viewer/presentation/pages/uml_viewer_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.user,
    this.authService,
    this.viewerRepository,
  });

  final AuthUser user;
  final AuthService? authService;
  final ViewerRepository? viewerRepository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ViewerRepository _repository =
      widget.viewerRepository ??
      MobileViewerRepository(userId: '${widget.user.id}');
  final _searchController = TextEditingController();
  List<UmlProjectSummary> _projects = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final projects = await _repository.loadProjects();
      if (mounted) setState(() => _projects = projects);
    } on ViewerRepositoryException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo cargar la lista de proyectos.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await AuthSessionManager.logoutAndClear(authService: widget.authService);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(authService: widget.authService),
      ),
      (_) => false,
    );
  }

  void _open(UmlProjectSummary project) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UmlViewerPage(
          project: project,
          repository: _repository,
          remoteRevisions: _repository.watchRemoteRevisions(project.id),
        ),
      ),
    );
  }

  List<UmlProjectSummary> get _filteredProjects {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _projects;
    return _projects
        .where((project) {
          return project.name.toLowerCase().contains(query) ||
              project.access.name.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('home-page'),
      appBar: AppBar(
        title: const Text('Proyectos UML'),
        actions: [
          IconButton(
            key: const ValueKey('refresh-projects'),
            tooltip: 'Actualizar proyectos',
            onPressed: _loading ? null : _loadProjects,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            key: const ValueKey('logout-button'),
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProjects,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, ${widget.user.firstName}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.user.fullName,
                      key: const ValueKey('home-user-name'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      widget.user.email,
                      key: const ValueKey('home-user-email'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('project-search'),
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Buscar por nombre o permiso',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: _HomeMessage(
                  icon: Icons.cloud_off_outlined,
                  message: _error!,
                  action: FilledButton.tonal(
                    onPressed: _loadProjects,
                    child: const Text('Reintentar'),
                  ),
                ),
              )
            else if (_filteredProjects.isEmpty)
              const SliverFillRemaining(
                child: _HomeMessage(
                  icon: Icons.folder_open_outlined,
                  message: 'No hay proyectos que coincidan con la búsqueda.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                sliver: SliverList.builder(
                  itemCount: _filteredProjects.length,
                  itemBuilder: (context, index) {
                    final project = _filteredProjects[index];
                    return _ProjectCard(
                      project: project,
                      onOpen: () => _open(project),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onOpen});
  final UmlProjectSummary project;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final stateLabel = switch (project.syncState) {
      ViewerSyncState.updated => 'Actualizado',
      ViewerSyncState.offline => 'Offline',
      ViewerSyncState.pending => 'Pendiente',
      ViewerSyncState.conflict => 'Conflicto',
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Semantics(
        button: true,
        label:
            'Abrir ${project.name}, permiso ${_accessLabel(project.access)}, $stateLabel',
        child: ListTile(
          key: ValueKey('project-${project.id}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.account_tree_outlined),
          ),
          title: Text(
            project.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(_accessLabel(project.access)),
                Text(stateLabel),
                Text(_relativeDate(project.updatedAt)),
                Text('rev. ${project.revision}'),
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onOpen,
        ),
      ),
    );
  }
}

class _HomeMessage extends StatelessWidget {
  const _HomeMessage({required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

String _accessLabel(ProjectAccess access) => switch (access) {
  ProjectAccess.owner => 'Propietario',
  ProjectAccess.editor => 'Editor',
  ProjectAccess.viewer => 'Lector',
};

String _relativeDate(DateTime? value) {
  if (value == null) return 'Sin fecha';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}
