# Etapa 2A — aplicar no Supabase antes de publicar o PR

O diagnóstico de 25/09/2026 confirmou 45 políticas e 34 tabelas públicas
com RLS ativo. As políticas amplas de leitura do antigo script de pendências
não estavam aplicadas. O problema real era diferente: `usuarios` permitia
apenas ler o próprio registro; a leitura de `pessoas` dependia de ADMIN;
e as políticas `admin_total_*` não limitavam a empresa.

## Executar

1. Abrir o projeto NEXO em Supabase > SQL Editor > New query.
2. Usar o papel `postgres` do SQL Editor.
3. Colar e executar **todo** `sql/002_acesso_empresa.sql`.
4. O resultado esperado é `ETAPA 2A APLICADA`.
5. Enviar o resultado ou o erro completo antes de publicar o frontend.

O arquivo altera funções, políticas, um trigger de proteção de pessoas e a
permissão de UPDATE de `usuarios`. Não apaga nem atualiza registros existentes.
Possui transação, limite de espera por locks e pode ser reaplicado.
Se ocorrer erro antes do COMMIT, nenhuma alteração dessa transação será aplicada.

## Resultado esperado

- Usuário ativo consegue ler o cadastro necessário ao login e os catálogos
  básicos da própria empresa.
- ADMIN lista e altera perfil/ativo dos usuários da própria empresa.
- A API não permite trocar `usuarios.id` ou `usuarios.pessoa_id` via UPDATE.
- ADMIN não altera o próprio acesso pela aplicação. Outro ADMIN deve fazê-lo.
- O último ADMIN ativo é protegido por empresa na alteração de acesso.
- Para inativar uma pessoa com login, primeiro desativar seu acesso. Transferir
  uma pessoa com login entre empresas exige migração administrativa específica.
- Políticas restritivas limitam as permissões existentes à empresa ou ao escopo
  de execução. A leitura mínima do próprio cadastro permanece para informar
  inativação. Registros sem vínculo de empresa identificável ficam inacessíveis
  pela API; por exemplo, alertas/auditoria sem pessoa vinculada.

## Limites desta etapa

Não adiciona permissões de escrita operacional para novos perfis. Demandas,
documentos e várias outras tabelas continuam com escrita restrita pelas regras
anteriores. A separação entre executar, conferir e aprovar é a próxima etapa:
as policies `nexo_final_*_all` ainda precisam ser substituídas por regras de ação.
Storage, funções RPC operacionais e dados existentes não são migrados aqui.
Esta etapa não é uma certificação completa de isolamento de todas as relações
ou de funções SECURITY DEFINER que executam fora de RLS.

## Testes e reversão

`npm test` inclui PostgreSQL local via PGlite, com metadados do diagnóstico e
dados fictícios de duas empresas. Verifica leitura para login, acesso ADMIN,
inativação, tentativa de elevar o próprio perfil, alteração da identidade,
limite por empresa, proteção de pessoa, último ADMIN, reaplicação e reversão.
O fixture não reproduz todas as constraints, FKs, Supabase Auth ou Storage.
Os testes locais não executam operações no Supabase real.

Para recuperação, executar todo `sql/002_reverter_acesso_empresa.sql` no SQL
Editor como postgres. A reversão restaura as funções e privilégios anteriores
e remove as políticas desta etapa, reintroduzindo as limitações do diagnóstico.

Após aplicar, validar na prévia do PR uma conta ADMIN e uma conta comum.
A atualização do frontend também deixa de informar sucesso se a alteração de
acesso não retornar o registro atualizado (zero linhas afetadas).
