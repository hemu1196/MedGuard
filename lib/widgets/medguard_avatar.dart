import 'package:flutter/material.dart';
import '../core/utils/image_helper.dart';
import '../services/user_state_service.dart';

/// Reusable MEDGUARD Avatar supporting:
/// - State A (No Image): Teal circle (#00BFA5) with uppercase name initial in bold white text
/// - State B (Image Uploaded): Persistent cloud image from MongoDB Atlas GridFS with cache-busting
/// - State C (Image Removed): Instant clean revert to State A initial
class MedGuardAvatar extends StatelessWidget {
  final double radius;
  final String? imageUrl;
  final String? name;
  final double borderWidth;
  final Color borderColor;
  final VoidCallback? onTap;
  final bool showEditBadge;
  final VoidCallback? onEditTap;

  const MedGuardAvatar({
    super.key,
    this.radius = 20,
    this.imageUrl,
    this.name,
    this.borderWidth = 0,
    this.borderColor = Colors.white,
    this.onTap,
    this.showEditBadge = false,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProfileStateManager.instance,
      builder: (context, _) {
        final state = ProfileStateManager.instance;
        final rawPath = imageUrl ?? state.profileImagePath;
        final resolvedName = name ?? state.currentProfile?.name ?? '';
        final initial = resolvedName.trim().isNotEmpty
            ? resolvedName.trim()[0].toUpperCase()
            : state.initial;

        Widget avatarContent;

        if (rawPath != null && rawPath.trim().isNotEmpty) {
          String resolvedUrl = ImageHelper.resolveUrl(rawPath.trim()) ?? rawPath.trim();
          // Append cache-busting version parameter for network URLs
          if (resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://')) {
            final separator = resolvedUrl.contains('?') ? '&' : '?';
            resolvedUrl = '$resolvedUrl${separator}v=${state.avatarVersion}';
          }

          avatarContent = ClipOval(
            child: SizedBox(
              width: radius * 2,
              height: radius * 2,
              child: ImageHelper.buildImage(
                resolvedUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: _buildStateAInitial(initial),
                errorWidget: _buildStateAInitial(initial),
              ),
            ),
          );
        } else {
          // State A / State C: Teal circular initial
          avatarContent = _buildStateAInitial(initial);
        }

        Widget avatarWidget = Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: borderWidth > 0
                ? Border.all(color: borderColor, width: borderWidth)
                : null,
          ),
          child: avatarContent,
        );

        if (onTap != null) {
          avatarWidget = GestureDetector(
            onTap: onTap,
            child: avatarWidget,
          );
        }

        if (showEditBadge) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              avatarWidget,
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onEditTap ?? onTap,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFA5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return avatarWidget;
      },
    );
  }

  Widget _buildStateAInitial(String initial) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        color: Color(0xFF00BFA5), // Medical Teal Accent
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.85,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
