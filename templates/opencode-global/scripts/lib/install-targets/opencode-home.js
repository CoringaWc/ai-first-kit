const fs = require('fs');
const path = require('path');

const {
  createInstallTargetAdapter,
  createRemappedOperation,
  isForeignPlatformPath,
  normalizeRelativePath,
} = require('./helpers');

const OPENCODE_ECC_SKILL_PREFIX = 'ecc-';

function slugifyPathSegment(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/^['"]|['"]$/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 64);
}

function readSkillOrigin(repoRoot, skillId) {
  const skillPath = path.join(repoRoot || '', 'skills', skillId, 'SKILL.md');
  if (!repoRoot || !fs.existsSync(skillPath)) {
    return '';
  }

  const content = fs.readFileSync(skillPath, 'utf8');
  const match = content.match(/^origin:\s*([^\n]+)$/m);
  return match ? match[1].trim() : '';
}

function getEccSkillGroupSegments(origin) {
  const normalizedOrigin = String(origin || '').trim().replace(/\r$/, '');
  const lowerOrigin = normalizedOrigin.toLowerCase();

  if (lowerOrigin === 'ecc') {
    return [];
  }

  if (!normalizedOrigin) {
    return ['community', 'unknown'];
  }

  if (lowerOrigin === 'ecc direct-port adaptation') {
    return ['direct-port'];
  }

  if (lowerOrigin.startsWith('health1 super speciality hospitals')) {
    return ['health1'];
  }

  if (lowerOrigin === 'community' || lowerOrigin === 'ecc-community') {
    return ['community'];
  }

  const slug = slugifyPathSegment(normalizedOrigin.split(/\s+[—–-]\s+/)[0]);
  return slug ? ['community', slug] : ['community'];
}

function getOpencodeManagedDestinationPath(adapter, sourceRelativePath, input) {
  const normalizedSourcePath = normalizeRelativePath(sourceRelativePath);
  const targetRoot = adapter.resolveRoot(input);

  if (normalizedSourcePath.startsWith('skills/')) {
    const skillRelativePath = normalizedSourcePath.slice('skills/'.length);
    const [skillId, ...rest] = skillRelativePath.split('/');
    if (!skillId) {
      return null;
    }

    return path.join(
      targetRoot,
      'ecc',
      'skills',
      'ecc',
      ...getEccSkillGroupSegments(readSkillOrigin(input.repoRoot, skillId)),
      `${OPENCODE_ECC_SKILL_PREFIX}${skillId}`,
      ...rest
    );
  }

  return null;
}

module.exports = createInstallTargetAdapter({
  id: 'opencode-home',
  target: 'opencode',
  kind: 'home',
  rootSegments: ['.config', 'opencode'],
  installStatePathSegments: ['ecc', 'ecc-install-state.json'],
  nativeRootRelativePath: '.opencode',
  planOperations(input, adapter) {
    const modules = Array.isArray(input.modules)
      ? input.modules
      : (input.module ? [input.module] : []);
    const planningInput = {
      repoRoot: input.repoRoot,
      projectRoot: input.projectRoot,
      homeDir: input.homeDir,
    };

    return modules.flatMap(module => {
      const paths = Array.isArray(module.paths) ? module.paths : [];
      return paths
        .filter(p => !isForeignPlatformPath(p, adapter.target))
        .map(sourceRelativePath => {
          const managedDestinationPath = getOpencodeManagedDestinationPath(
            adapter,
            sourceRelativePath,
            planningInput
          );

          if (managedDestinationPath) {
            return createRemappedOperation(
              adapter,
              module.id,
              sourceRelativePath,
              managedDestinationPath,
              {
                strategy: 'preserve-relative-path',
                extra: { transform: 'opencode-ecc-skill-prefix' },
              }
            );
          }

          return adapter.createScaffoldOperation(module.id, sourceRelativePath, planningInput);
        });
    });
  },
});
