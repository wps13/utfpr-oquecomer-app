import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../routing/route_observer.dart';
import '../../../routing/routes.dart';
import '../view_models/hands_free_mode_viewmodel.dart';
import 'hands_free_mode_body.dart';

class HandsFreeModeScreen extends StatefulWidget {
  const HandsFreeModeScreen({super.key});

  @override
  State<HandsFreeModeScreen> createState() => _HandsFreeModeScreenState();
}

class _HandsFreeModeScreenState extends State<HandsFreeModeScreen>
    with RouteAware {
  late final HandsFreeModeViewModel _viewModel;
  bool _leaving = false;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<HandsFreeModeViewModel>();
    _viewModel.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_viewModel.load());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() => _viewModel.setVisible(visible: false);

  @override
  void didPop() => _viewModel.setVisible(visible: false);

  @override
  void didPopNext() => _viewModel.setVisible(visible: true);

  void _onChange() {
    if (!_viewModel.exitRequested || _leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _leave();
    });
  }

  void _leave() {
    if (_didNavigate) return;
    _didNavigate = true;
    unawaited(_viewModel.suspend());
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _viewModel.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo mãos livres'),
        leading: BackButton(onPressed: _leave),
      ),
      body: SafeArea(child: HandsFreeModeBody(onExit: _leave)),
    );
  }
}
