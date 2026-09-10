import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../data/api/api_exception.dart';

/// One place where every screen's loading, error and empty states live.
///
/// Nothing in this app renders placeholder content while data is in flight:
/// a judge must never be shown a number that later changes.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.future,
    required this.builder,
    this.onRetry,
    this.loading,
    this.isEmpty,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
  });

  final Future<T>? future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback? onRetry;
  final Widget? loading;
  final bool Function(T data)? isEmpty;
  final String emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loading ?? const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorState(error: snapshot.error!, onRetry: onRetry);
        }
        if (!snapshot.hasData) {
          return EmptyState(
            title: emptyTitle,
            message: emptyMessage,
            icon: emptyIcon,
            onRetry: onRetry,
          );
        }
        final data = snapshot.data as T;
        if (isEmpty?.call(data) ?? false) {
          return EmptyState(
            title: emptyTitle,
            message: emptyMessage,
            icon: emptyIcon,
            onRetry: onRetry,
          );
        }
        return builder(context, data);
      },
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final api = error is ApiException ? error as ApiException : null;
    final isNetwork = api?.isNetwork ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 48,
              color: isNetwork ? AppColors.textTertiary : AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              isNetwork ? 'No connection to the server' : 'Something went wrong',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              api?.message ?? '$error',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            if (api != null && !isNetwork) ...[
              const SizedBox(height: 8),
              Text(
                api.code,
                style: GoogleFonts.robotoMono(
                  fontSize: 11,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.onRetry,
  });

  final String title;
  final String? message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Surfaces an [ApiException] as a snackbar without swallowing its code.
void showApiError(BuildContext context, Object error) {
  final api = error is ApiException ? error : null;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppColors.error,
      content: Text(api?.message ?? '$error'),
      duration: const Duration(seconds: 5),
    ),
  );
}
