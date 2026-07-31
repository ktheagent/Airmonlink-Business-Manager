from pathlib import Path
import re, sys, json
import yaml
root=Path(sys.argv[1]).resolve()
results=[]
def record(name, ok, detail='', level=None):
    status = level or ('PASS' if ok else 'FAIL')
    results.append((name, status, str(detail)))

# Required files
required=[
'pubspec.yaml','lib/main.dart','lib/services/database_service.dart','lib/state/app_state.dart',
'lib/commercial/services/commercial_service.dart','lib/commercial/screens/commercial_suite_screen.dart',
'lib/services/backup_service.dart','.github/workflows/windows-release.yml','installer/airmonlink_business_manager.iss',
'test/commercial_service_test.dart','FINAL-RELEASE-AUDIT.md']
missing=[p for p in required if not (root/p).is_file()]
record('required source files',not missing, 'missing='+','.join(missing) if missing else f'{len(required)} present')

# YAML
for rel in ['pubspec.yaml','.github/workflows/windows-release.yml']:
    try:
        yaml.safe_load((root/rel).read_text(encoding='utf-8'))
        record(f'YAML parse {rel}',True,'parsed')
    except Exception as e: record(f'YAML parse {rel}',False,e)

# Identity
identity_files={
'pubspec.yaml':r'version:\s*1\.3\.0\+8',
'lib/core/app_constants.dart':r"version\s*=\s*'1\.3\.0\+8'",
'installer/airmonlink_business_manager.iss':r'Build8-Setup',
'tool/package_windows.ps1':r'Build8-Portable\.zip',
'.github/workflows/windows-release.yml':r'Build8-Windows',
}
for rel,pat in identity_files.items():
    txt=(root/rel).read_text(encoding='utf-8')
    record(f'Build 8 identity {rel}',bool(re.search(pat,txt)),pat)

# Relative imports
bad_import=[]
for p in list((root/'lib').rglob('*.dart'))+list((root/'test').rglob('*.dart')):
    txt=p.read_text(encoding='utf-8')
    for m in re.finditer(r"(?:import|export|part)\s+['\"]([^'\"]+)['\"]",txt):
        uri=m.group(1)
        if uri.startswith(('.', '..')):
            q=(p.parent/uri).resolve()
            if not q.exists(): bad_import.append(f'{p.relative_to(root)} -> {uri}')
record('relative Dart imports',not bad_import, '; '.join(bad_import[:10]) if bad_import else 'all resolved')

# Dart lexical delimiter scan (not a compiler)
def scan(text):
    stack=[]; i=0; line=1; errors=[]
    pairs={')':'(',']':'[','}':'{'}
    while i<len(text):
        c=text[i]
        if c=='\n': line+=1; i+=1; continue
        if text.startswith('//',i):
            j=text.find('\n',i+2); i=len(text) if j<0 else j; continue
        if text.startswith('/*',i):
            depth=1; i+=2
            while i<len(text) and depth:
                if text.startswith('/*',i): depth+=1;i+=2
                elif text.startswith('*/',i): depth-=1;i+=2
                else:
                    if text[i]=='\n': line+=1
                    i+=1
            if depth: errors.append(f'unclosed block comment line {line}')
            continue
        raw=False
        if c in 'rR' and i+1<len(text) and text[i+1] in "'\"": raw=True;i+=1;c=text[i]
        if c in "'\"":
            quote=c; triple=text.startswith(c*3,i); i+=3 if triple else 1
            while i<len(text):
                if text[i]=='\n': line+=1
                if triple and text.startswith(quote*3,i): i+=3; break
                if not triple and text[i]==quote: i+=1; break
                if not raw and text[i]=='\\': i+=2
                else: i+=1
            else: errors.append(f'unclosed string line {line}')
            continue
        if c in '([{': stack.append((c,line))
        elif c in ')]}':
            if not stack or stack[-1][0]!=pairs[c]: errors.append(f'unmatched {c} line {line}')
            else: stack.pop()
        i+=1
    errors += [f'unclosed {c} line {ln}' for c,ln in stack]
    return errors
lex_errors=[]
files=list((root/'lib').rglob('*.dart'))+list((root/'test').rglob('*.dart'))
for p in files:
    errs=scan(p.read_text(encoding='utf-8'))
    lex_errors += [f'{p.relative_to(root)}: {e}' for e in errs]
record('Dart lexical delimiter scan',not lex_errors, f'{len(files)} files; '+('; '.join(lex_errors[:10]) if lex_errors else 'no structural imbalance'))

# No backup/editor temp files
temps=[str(p.relative_to(root)) for p in root.rglob('*') if p.is_file() and (p.suffix in {'.bak','.tmp'} or p.name.endswith('~'))]
record('no backup/editor files',not temps, ', '.join(temps) if temps else 'none')

# No hard-coded obvious secrets
secret_re=re.compile(r"(?i)(password|api[_-]?key|secret|token)\s*[:=]\s*['\"]([^'\"]{4,})['\"]")
secrets=[]
for p in (root/'lib').rglob('*.dart'):
    for m in secret_re.finditer(p.read_text(encoding='utf-8')):
        value=m.group(2)
        if value.lower() not in {'password','token','secret','api-key'}:
            secrets.append(f'{p.relative_to(root)}:{m.group(1)}')
record('hard-coded secret pattern scan',not secrets, ', '.join(secrets[:10]) if secrets else 'none')

# Schema table count
text=(root/'lib/services/database_service.dart').read_text(encoding='utf-8')
tables=sorted(set(re.findall(r'CREATE TABLE(?: IF NOT EXISTS)?\s+([A-Za-z_]+)',text)))
record('commercial schema table count',len(tables)==41,f'{len(tables)} tables')
record('database schema version',bool(re.search(r'schemaVersion\s*=\s*8',text)),'expected 8')

# Ensure licence regression tests remain
testtext=(root/'test/license_service_test.dart').read_text(encoding='utf-8')
needed=['never extends expiry','paid activation immediately replaces','remains revoked offline']
record('Build 6 licensing regression sources',all(s in testtext for s in needed),', '.join(needed))

# Known package lock state
lock=(root/'pubspec.lock').read_text(encoding='utf-8') if (root/'pubspec.lock').exists() else ''
newdeps=['cryptography','excel','file_picker','mailer']
missing_lock=[d for d in newdeps if re.search(rf'^  {re.escape(d)}:',lock,re.M) is None]
record('Build 8 dependency lockfile',not missing_lock,'missing: '+', '.join(missing_lock)+'; run flutter pub get in CI' if missing_lock else 'contains Build 8 dependencies', level='WARN' if missing_lock else 'PASS')

# Test inventory
names=[]
for p in (root/'test').glob('*.dart'):
    names += re.findall(r"test\(\s*['\"]([^'\"]+)",p.read_text(encoding='utf-8'))
record('source test inventory',len(names)>=20,f'{len(names)} directly detected test declarations')

out=[]
for name,status,detail in results:
    out.append(f"{status} | {name} | {detail}")
summary={'passed':sum(x[1]=='PASS' for x in results),'warnings':sum(x[1]=='WARN' for x in results),'failed':sum(x[1]=='FAIL' for x in results),'checks':len(results)}
print('\n'.join(out))
print('SUMMARY | '+json.dumps(summary))
(root/'BUILD8-SOURCE-VALIDATION.txt').write_text('\n'.join(out)+'\nSUMMARY | '+json.dumps(summary)+'\n',encoding='utf-8')
sys.exit(1 if summary['failed'] else 0)
