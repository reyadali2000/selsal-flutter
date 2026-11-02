import '../constants/app_colors.dart';
import 'package:flutter/material.dart';

class ProductSizeCard extends StatelessWidget {
  final String size;
  final String imagePath;
  final bool isSelected;
  final VoidCallback onTap;

  const ProductSizeCard({
    super.key,
    required this.size,
    required this.imagePath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Card
          Container(
            height: 170, // Increased height to prevent overflow
            margin: const EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              color: Colors.white, // Changed to white as requested
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? AppColors.primaryDark : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                // Left Side: Small Icon (using the same image scaled down with a label)
                Container(
                  width: 100,
                  padding: const EdgeInsets.all(8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(imagePath, height: 110, opacity: const AlwaysStoppedAnimation(0.5)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          size,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                ),
                
                // Center: Texts
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        size,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark, // Dark blue text
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'مياه معدنية طبيعية',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'العبوة: $size',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!isSelected)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'اختر',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward, size: 16, color: AppColors.primaryDark),
                          ],
                        ),
                    ],
                  ),
                ),
                
                // Spacer for right image
                const SizedBox(width: 100),
              ],
            ),
          ),
          
          // Protruding Image on the RIGHT
          Positioned(
            top: 0, // Protrudes upwards
            right: -10, // Protrudes rightwards
            child: IgnorePointer(
              child: Transform.rotate(
                angle: 0.1, // Slight tilt as in design
                child: SizedBox(
                  height: 180, // Large size
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

