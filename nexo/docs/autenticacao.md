# Sessão e acesso — etapa 1

Atualização: o diagnóstico já foi recebido. Para a migração da etapa 2A,
seguir `docs/etapa-2-acesso.md` e aplicar `sql/002_acesso_empresa.sql`
antes de publicar o PR que inclui as alterações de administração de acessos.

O frontend usa Supabase Auth com e-mail/senha. `src/lib/supabase.ts`
cria o cliente compartilhado; URL e chave pública vêm de `VITE_SUPABASE_URL`
e `VITE_SUPABASE_ANON_KEY`. Nunca colocar service_role em variáveis VITE.

## Comportamento

- `useUsuario` acompanha a sessão, recupera o cadastro e descarta respostas
  antigas após logout ou uma validação mais recente.
- A revalidação também ocorre ao voltar à aba, focar a janela ou recuperar
  a conexão. Alterações de perfil não são notificadas em tempo real.
- A consulta exige usuário ativo, pessoa ativa e vínculos válidos com pessoa,
  empresa e perfil. Falhas removem o perfil antigo da interface.
- A senha é limpa após cada tentativa de login. O formulário impede reenvio
  enquanto a requisição está em andamento.
- Logout só apresenta sucesso após a chamada ao Supabase; erros aparecem
  na tela e permitem nova tentativa.
- As páginas administrativas verificam ADMIN tanto na navegação quanto
  na renderização. Essa guarda não substitui RLS e permissões SQL.
- A persistência e renovação da sessão seguem os padrões do SDK. Não há
  cookie HttpOnly ou implementação própria de armazenamento de tokens.

## Banco de dados: responsabilidade do operador

Esta etapa não exige migração: usa os campos já referenciados no projeto.
Não modifica automaticamente o Supabase.

1. Abrir o projeto NEXO no Supabase.
2. SQL Editor > New query.
3. Colar `sql/001_diagnostico_acesso.sql` e clicar Run.
4. Copiar o JSON da coluna `diagnostico` ou exportar o resultado e enviá-lo
   para preparar a migração de permissões.

O diagnóstico consulta somente metadados. Não executar novamente os scripts
antigos como parte desta etapa. A consolidação de RLS e as transações do fluxo
operacional dependem da revisão das regras e do esquema efetivamente aplicados.

## Validação

Executar `npm ci`, `npm test` e `npm run build` dentro de `nexo/`.
Os testes usam mocks; não acessam o banco real.

Na prévia do PR, validar login válido/inválido, atualização da página,
logout, inativação e mudança de perfil ao voltar à aba. Confirmar que uma
conta comum não abre Administração. A proteção de dados via API só pode ser
confirmada com testes no Supabase após revisar as políticas.

Publicação: incorporar o PR na main apenas após revisar a prévia. Se o
Vercel estiver vinculado à main, o merge poderá publicar automaticamente.
Reversão do frontend: reverter o commit/PR; esta etapa não altera o banco.
