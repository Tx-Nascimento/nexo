#!/usr/bin/env bash
set -euo pipefail

APP="/workspaces/nexo/nexo"
cd "$APP"

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$APP/.nexo_backup_$STAMP"
mkdir -p "$BACKUP/src/pages" "$BACKUP/src/components" "$BACKUP/src/lib"

for f in \
  src/pages/OperacoesPage.tsx \
  src/pages/CentralPage.tsx \
  src/pages/IndicadoresPage.tsx \
  src/pages/PessoasGeralPage.tsx \
  src/App.css
do
  if [ -f "$f" ]; then
    mkdir -p "$BACKUP/$(dirname "$f")"
    cp "$f" "$BACKUP/$f"
  fi
done

echo "Backup criado em: $BACKUP"

cat > src/components/ChecklistConclusao.tsx <<'NEXO_EOF'
import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'

type Props = {
  execucaoId: string
  operacaoId: string
  status: string
  onConcluir: () => Promise<void> | void
}

type Estado = {
  exigeConferencia: boolean
  exigeAprovacao: boolean
  exigeEvidencia: boolean
  bloqueios: number
  dependencias: number
  retrabalhos: number
  conferenciaAprovada: boolean
  aprovacaoAprovada: boolean
  evidencias: number
}

const vazio: Estado = {
  exigeConferencia: false,
  exigeAprovacao: false,
  exigeEvidencia: false,
  bloqueios: 0,
  dependencias: 0,
  retrabalhos: 0,
  conferenciaAprovada: false,
  aprovacaoAprovada: false,
  evidencias: 0,
}

export default function ChecklistConclusao({
  execucaoId,
  operacaoId,
  status,
  onConcluir,
}: Props) {
  const [estado, setEstado] = useState<Estado>(vazio)
  const [carregando, setCarregando] = useState(true)
  const [erro, setErro] = useState('')

  useEffect(() => {
    let ativo = true

    async function carregar() {
      try {
        setCarregando(true)
        setErro('')

        const [op, b, d, r, c, a, e] = await Promise.all([
          supabase
            .from('operacoes')
            .select('exige_conferencia,exige_aprovacao,exige_evidencia')
            .eq('id', operacaoId)
            .single(),
          supabase
            .from('bloqueios')
            .select('id', { count: 'exact', head: true })
            .eq('execucao_id', execucaoId)
            .eq('ativo', true),
          supabase
            .from('dependencias')
            .select('id', { count: 'exact', head: true })
            .eq('execucao_id', execucaoId)
            .eq('ativo', true),
          supabase
            .from('retrabalhos')
            .select('id', { count: 'exact', head: true })
            .eq('execucao_id', execucaoId)
            .in('status', ['PENDENTE', 'EM_CORRECAO']),
          supabase
            .from('conferencias')
            .select('id', { count: 'exact', head: true })
            .eq('execucao_id', execucaoId)
            .eq('resultado', 'APROVADA'),
          supabase
            .from('aprovacoes')
            .select('id', { count: 'exact', head: true })
            .eq('execucao_id', execucaoId)
            .eq('status', 'APROVADA'),
          supabase
            .from('evidencias')
            .select('id', { count: 'exact', head: true })
            .eq('execucao_id', execucaoId),
        ])

        for (const resp of [op, b, d, r, c, a, e]) {
          if (resp.error) throw resp.error
        }

        if (!ativo) return

        setEstado({
          exigeConferencia: !!op.data?.exige_conferencia,
          exigeAprovacao: !!op.data?.exige_aprovacao,
          exigeEvidencia: !!op.data?.exige_evidencia,
          bloqueios: b.count || 0,
          dependencias: d.count || 0,
          retrabalhos: r.count || 0,
          conferenciaAprovada: (c.count || 0) > 0,
          aprovacaoAprovada: (a.count || 0) > 0,
          evidencias: e.count || 0,
        })
      } catch (error: any) {
        if (ativo) setErro(error?.message || 'Não foi possível validar a conclusão.')
      } finally {
        if (ativo) setCarregando(false)
      }
    }

    carregar()
    return () => {
      ativo = false
    }
  }, [execucaoId, operacaoId, status])

  const itens = useMemo(() => [
    {
      label: 'Sem bloqueio ativo',
      ok: estado.bloqueios === 0,
      detalhe: estado.bloqueios ? `${estado.bloqueios} bloqueio(s) aberto(s)` : 'OK',
    },
    {
      label: 'Sem dependência ativa',
      ok: estado.dependencias === 0,
      detalhe: estado.dependencias ? `${estado.dependencias} dependência(s) aberta(s)` : 'OK',
    },
    {
      label: 'Sem retrabalho pendente',
      ok: estado.retrabalhos === 0,
      detalhe: estado.retrabalhos ? `${estado.retrabalhos} retrabalho(s) pendente(s)` : 'OK',
    },
    {
      label: 'Conferência',
      ok: !estado.exigeConferencia || estado.conferenciaAprovada,
      detalhe: estado.exigeConferencia
        ? estado.conferenciaAprovada ? 'Aprovada' : 'Obrigatória e pendente'
        : 'Não exigida',
    },
    {
      label: 'Aprovação',
      ok: !estado.exigeAprovacao || estado.aprovacaoAprovada,
      detalhe: estado.exigeAprovacao
        ? estado.aprovacaoAprovada ? 'Aprovada' : 'Obrigatória e pendente'
        : 'Não exigida',
    },
    {
      label: 'Evidência',
      ok: !estado.exigeEvidencia || estado.evidencias > 0,
      detalhe: estado.exigeEvidencia
        ? estado.evidencias > 0 ? `${estado.evidencias} registrada(s)` : 'Obrigatória e ausente'
        : `${estado.evidencias} registrada(s)`,
    },
  ], [estado])

  const pronta = itens.every((x) => x.ok)
  const encerrada = ['CONCLUIDA', 'CANCELADA'].includes(status)

  return (
    <div className="nexo-conclusion-check">
      <div className="nexo-conclusion-title">
        <div>
          <h4>Prontidão para concluir</h4>
          <p>
            {carregando
              ? 'Validando requisitos...'
              : pronta
                ? 'Todos os requisitos foram atendidos.'
                : 'Existem pendências que impedem a conclusão.'}
          </p>
        </div>
        {!carregando && (
          <span className={pronta ? 'nexo-ready-badge ready' : 'nexo-ready-badge pending'}>
            {pronta ? 'PRONTA' : 'PENDENTE'}
          </span>
        )}
      </div>

      {erro && <div className="system-message">{erro}</div>}

      <div className="nexo-check-list">
        {itens.map((item) => (
          <div className={item.ok ? 'nexo-check-item ok' : 'nexo-check-item pendente'} key={item.label}>
            <span>{item.ok ? '✓' : '!'}</span>
            <div>
              <strong>{item.label}</strong>
              <small>{item.detalhe}</small>
            </div>
          </div>
        ))}
      </div>

      <button
        className="primary-button"
        onClick={onConcluir}
        disabled={carregando || !pronta || encerrada}
      >
        {encerrada ? 'Execução encerrada' : pronta ? 'Concluir execução' : 'Resolva as pendências para concluir'}
      </button>
    </div>
  )
}
NEXO_EOF

cat > src/lib/hierarquia.ts <<'NEXO_EOF'
export const PERFIS_EMPRESA = ['ADMIN', 'DIRETORIA', 'AUDITOR']
export const PERFIS_SETOR = ['LIDER', 'GESTOR', 'GERENTE']

export function escopoPerfil(
  perfil: string,
  pessoaId: string,
  setorId: string | null,
  alvoPessoaId: string,
  alvoSetorId: string | null
) {
  if (PERFIS_EMPRESA.includes(perfil)) return true
  if (alvoPessoaId === pessoaId) return true
  if (PERFIS_SETOR.includes(perfil)) return !!setorId && alvoSetorId === setorId
  return false
}

export function podeVerEmpresa(perfil: string) {
  return PERFIS_EMPRESA.includes(perfil)
}
NEXO_EOF

python3 <<'PY'
from pathlib import Path
import re

op = Path("src/pages/OperacoesPage.tsx")
if not op.exists():
    raise SystemExit("ERRO: src/pages/OperacoesPage.tsx não encontrado.")

txt = op.read_text(encoding="utf-8")

imp = "import ChecklistConclusao from '../components/ChecklistConclusao'\n"
if imp not in txt:
    anchor = "import type { DadosUsuario } from '../types'\n"
    if anchor not in txt:
        raise SystemExit("ERRO: âncora de import não encontrada em OperacoesPage.tsx.")
    txt = txt.replace(anchor, anchor + imp, 1)

# Remove CONCLUIDA da troca manual de status: conclusão passa pelo checklist/RPC.
txt = txt.replace(
"""  'BLOQUEADA',
  'CONCLUIDA',
  'CANCELADA',""",
"""  'BLOQUEADA',
  'CANCELADA',"""
)

# Troca a conclusão antiga por RPC transacional.
pattern = re.compile(
    r"  async function concluirExecucao\(\) \{.*?\n  \}\n\n  const resumo = useMemo",
    re.S,
)
replacement = """  async function concluirExecucao() {
    if (!selecionada) return

    if (!confirm('Concluir esta execução?')) return

    try {
      setMensagem('')

      const { error } = await supabase.rpc('nexo_concluir_execucao', {
        p_execucao_id: selecionada.id,
      })

      if (error) throw error

      setMensagem('Execução concluída com sucesso.')
      await carregarBase()
      await carregarDetalhes(selecionada.id)
    } catch (error: any) {
      console.error(error)
      setMensagem(
        error?.message ||
          'Não foi possível concluir. Verifique o checklist de conclusão.'
      )
    }
  }

  const resumo = useMemo"""
txt2, n = pattern.subn(replacement, txt, count=1)
if n != 1:
    raise SystemExit("ERRO: bloco concluirExecucao não localizado para substituição.")
txt = txt2

# Exige justificativa nas situações que pedem contexto.
old = """  async function alterarStatus(novoStatus: string) {
    if (!selecionada) return

    try {
      const statusAnterior = selecionada.status
      const agora = new Date().toISOString()
"""
new = """  async function alterarStatus(novoStatus: string) {
    if (!selecionada) return

    if (novoStatus === 'CONCLUIDA') {
      await concluirExecucao()
      return
    }

    const exigeMotivo = [
      'AGUARDANDO_INFORMACAO',
      'AGUARDANDO_TERCEIRO',
      'AGUARDANDO_CONFERENCIA',
      'AGUARDANDO_APROVACAO',
      'BLOQUEADA',
      'CANCELADA',
    ].includes(novoStatus)

    const motivo = exigeMotivo
      ? prompt('Informe o motivo desta alteração de status:')
      : 'Alteração realizada pela tela operacional'

    if (exigeMotivo && !motivo?.trim()) {
      setMensagem('Informe o motivo para alterar para este status.')
      return
    }

    try {
      const statusAnterior = selecionada.status
      const agora = new Date().toISOString()
"""
if old not in txt:
    raise SystemExit("ERRO: início de alterarStatus não localizado.")
txt = txt.replace(old, new, 1)

txt = txt.replace(
"""          motivo: 'Alteração realizada pela tela operacional',""",
"""          motivo: motivo?.trim() || 'Alteração realizada pela tela operacional',""",
1
)

# Substitui apenas a área final de conclusão por checklist.
pattern = re.compile(
    r"""          <div className="nexo-conclude-area">\s*<button\s*className="primary-button"\s*onClick=\{concluirExecucao\}\s*disabled=\{\s*selecionada\.status === 'CONCLUIDA' \|\|\s*selecionada\.status === 'CANCELADA'\s*\}\s*>\s*Concluir execução\s*</button>\s*</div>""",
    re.S,
)
replacement = """          <div className="nexo-conclude-area">
            <ChecklistConclusao
              execucaoId={selecionada.id}
              operacaoId={selecionada.operacao_id}
              status={selecionada.status}
              onConcluir={concluirExecucao}
            />
          </div>"""
txt2, n = pattern.subn(replacement, txt, count=1)
if n != 1:
    raise SystemExit("ERRO: área final de conclusão não localizada.")
op.write_text(txt2, encoding="utf-8")
print("OK: OperacoesPage.tsx atualizado")
PY

python3 <<'PY'
from pathlib import Path

# Central: ao abrir, gera recorrências e atualiza alertas sem interromper a tela
p = Path("src/pages/CentralPage.tsx")
if p.exists():
    t = p.read_text(encoding="utf-8")
    anchor = """        setCarregando(true)
        setMensagem('')
"""
    addition = """        setCarregando(true)
        setMensagem('')

        await Promise.allSettled([
          supabase.rpc('nexo_gerar_recorrencias'),
          supabase.rpc('nexo_atualizar_alertas'),
        ])
"""
    if "nexo_gerar_recorrencias" not in t and anchor in t:
        t = t.replace(anchor, addition, 1)
        p.write_text(t, encoding="utf-8")
        print("OK: CentralPage.tsx atualizado")
    else:
        print("INFO: CentralPage.tsx já possuía automações ou âncora diferente.")
PY

python3 <<'PY'
from pathlib import Path

# Corrige a pequena variável não usada, caso o arquivo tenha sido recriado por algum motivo.
p = Path("src/lib/gestao.ts")
if p.exists():
    t = p.read_text(encoding="utf-8")
    antigo = "for (const b of bloqFiltrados.filter((x) => x.ativo)) mapa.set('BLOQUEIO', (mapa.get('BLOQUEIO') || 0) + 1)"
    novo = "mapa.set('BLOQUEIO', (mapa.get('BLOQUEIO') || 0) + bloqFiltrados.filter((x) => x.ativo).length)"
    if antigo in t:
        t = t.replace(antigo, novo)
        p.write_text(t, encoding="utf-8")
        print("OK: gestao.ts corrigido")
PY

MARKER='NEXO - FECHAMENTO OPERACIONAL'
if ! grep -q "$MARKER" src/App.css; then
cat >> src/App.css <<'NEXO_EOF'

/* NEXO - FECHAMENTO OPERACIONAL */
.nexo-conclusion-check{width:100%;border:1px solid #e5e7eb;border-radius:12px;background:#fff;padding:18px;display:grid;gap:14px}
.nexo-conclusion-title{display:flex;justify-content:space-between;align-items:flex-start;gap:14px}
.nexo-conclusion-title h4{margin:0 0 5px;font-size:16px}
.nexo-conclusion-title p{margin:0;color:#6b7280;font-size:13px}
.nexo-ready-badge{font-size:11px;font-weight:900;border-radius:999px;padding:6px 10px;white-space:nowrap}
.nexo-ready-badge.ready{background:#ecfdf5;color:#166534}
.nexo-ready-badge.pending{background:#fff7ed;color:#9a3412}
.nexo-check-list{display:grid;grid-template-columns:repeat(3,1fr);gap:9px}
.nexo-check-item{display:flex;gap:9px;align-items:flex-start;border:1px solid #e5e7eb;border-radius:9px;padding:10px}
.nexo-check-item>span{display:flex;width:22px;height:22px;border-radius:50%;align-items:center;justify-content:center;font-weight:900;flex:0 0 22px}
.nexo-check-item div{display:flex;flex-direction:column;gap:2px}
.nexo-check-item strong{font-size:12px}
.nexo-check-item small{font-size:11px;color:#6b7280}
.nexo-check-item.ok{background:#f8fffb;border-color:#bbf7d0}
.nexo-check-item.ok>span{background:#dcfce7;color:#166534}
.nexo-check-item.pendente{background:#fffaf5;border-color:#fed7aa}
.nexo-check-item.pendente>span{background:#ffedd5;color:#9a3412}
.nexo-conclude-area{margin-top:20px}
.nexo-conclude-area .nexo-conclusion-check .primary-button{width:100%;justify-content:center}
@media(max-width:900px){.nexo-check-list{grid-template-columns:repeat(2,1fr)}}
@media(max-width:620px){.nexo-check-list{grid-template-columns:1fr}.nexo-conclusion-title{flex-direction:column}}
NEXO_EOF
fi

cat > supabase_nexo_fechamento.sql <<'NEXO_SQL'
-- ============================================================
-- NEXO - FECHAMENTO OPERACIONAL
-- Execute UMA VEZ no Supabase SQL Editor.
-- Mantém as tabelas atuais e adiciona segurança, conclusão,
-- recorrência e alertas.
-- ============================================================

reset role;

alter table public.pessoas
  add column if not exists gestor_id uuid null references public.pessoas(id) on delete set null;

alter table public.operacoes
  add column if not exists peso_complexidade numeric not null default 1;

alter table public.execucoes
  add column if not exists recorrencia_id uuid null references public.operacao_recorrencias(id) on delete set null;

alter table public.execucoes
  add column if not exists data_referencia date null;

create unique index if not exists ux_execucoes_recorrencia_data
on public.execucoes(recorrencia_id, data_referencia)
where recorrencia_id is not null and data_referencia is not null;

create index if not exists ix_execucoes_responsavel_status
on public.execucoes(responsavel_id, status);

create index if not exists ix_execucoes_prazo
on public.execucoes(data_prevista)
where status not in ('CONCLUIDA','CANCELADA');

create index if not exists ix_dependencias_execucao_ativa
on public.dependencias(execucao_id, ativo);

create index if not exists ix_bloqueios_execucao_ativo
on public.bloqueios(execucao_id, ativo);

create index if not exists ix_retrabalhos_execucao_status
on public.retrabalhos(execucao_id, status);

-- ------------------------------------------------------------
-- Helpers de usuário / hierarquia
-- ------------------------------------------------------------

create or replace function public.nexo_usuario_pessoa_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select u.pessoa_id
  from public.usuarios u
  where u.id = auth.uid()
    and u.ativo = true
  limit 1
$$;

create or replace function public.nexo_usuario_empresa_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select p.empresa_id
  from public.usuarios u
  join public.pessoas p on p.id = u.pessoa_id
  where u.id = auth.uid()
    and u.ativo = true
  limit 1
$$;

create or replace function public.nexo_usuario_setor_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select p.setor_id
  from public.usuarios u
  join public.pessoas p on p.id = u.pessoa_id
  where u.id = auth.uid()
    and u.ativo = true
  limit 1
$$;

create or replace function public.nexo_usuario_perfil()
returns text
language sql
security definer
stable
set search_path = public
as $$
  select pf.nome
  from public.usuarios u
  join public.perfis pf on pf.id = u.perfil_id
  where u.id = auth.uid()
    and u.ativo = true
  limit 1
$$;

create or replace function public.nexo_perfil_empresa()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(public.nexo_usuario_perfil() in ('ADMIN','DIRETORIA','AUDITOR'), false)
$$;

create or replace function public.nexo_perfil_setor()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(public.nexo_usuario_perfil() in ('LIDER','GESTOR','GERENTE'), false)
$$;

create or replace function public.nexo_pode_ver_pessoa(p_pessoa_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.pessoas alvo
    where alvo.id = p_pessoa_id
      and alvo.empresa_id = public.nexo_usuario_empresa_id()
      and (
        public.nexo_perfil_empresa()
        or alvo.id = public.nexo_usuario_pessoa_id()
        or (
          public.nexo_perfil_setor()
          and alvo.setor_id is not distinct from public.nexo_usuario_setor_id()
        )
        or alvo.gestor_id = public.nexo_usuario_pessoa_id()
      )
  )
$$;

create or replace function public.nexo_pode_ver_execucao(p_execucao_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.execucoes e
    join public.operacoes o on o.id = e.operacao_id
    where e.id = p_execucao_id
      and o.empresa_id = public.nexo_usuario_empresa_id()
      and (
        public.nexo_perfil_empresa()
        or e.responsavel_id = public.nexo_usuario_pessoa_id()
        or exists (
          select 1
          from public.execucao_participantes ep
          where ep.execucao_id = e.id
            and ep.pessoa_id = public.nexo_usuario_pessoa_id()
            and ep.ativo = true
        )
        or (
          public.nexo_perfil_setor()
          and o.setor_id is not distinct from public.nexo_usuario_setor_id()
        )
      )
  )
$$;

-- ------------------------------------------------------------
-- RLS operacional sem recursão
-- As policies ADMIN antigas podem continuar: policies permissivas somam OR.
-- ------------------------------------------------------------

alter table public.execucoes enable row level security;
drop policy if exists "nexo_final_execucoes_select" on public.execucoes;
create policy "nexo_final_execucoes_select"
on public.execucoes for select to authenticated
using (public.nexo_pode_ver_execucao(id));

drop policy if exists "nexo_final_execucoes_update" on public.execucoes;
create policy "nexo_final_execucoes_update"
on public.execucoes for update to authenticated
using (public.nexo_pode_ver_execucao(id))
with check (public.nexo_pode_ver_execucao(id));

do $$
declare
  t text;
begin
  foreach t in array array[
    'execucao_participantes',
    'execucao_status_historico',
    'dependencias',
    'bloqueios',
    'conferencias',
    'retrabalhos',
    'aprovacoes',
    'evidencias'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

drop policy if exists "nexo_final_participantes_all" on public.execucao_participantes;
create policy "nexo_final_participantes_all"
on public.execucao_participantes for all to authenticated
using (public.nexo_pode_ver_execucao(execucao_id))
with check (public.nexo_pode_ver_execucao(execucao_id));

drop policy if exists "nexo_final_historico_select" on public.execucao_status_historico;
create policy "nexo_final_historico_select"
on public.execucao_status_historico for select to authenticated
using (public.nexo_pode_ver_execucao(execucao_id));

drop policy if exists "nexo_final_historico_insert" on public.execucao_status_historico;
create policy "nexo_final_historico_insert"
on public.execucao_status_historico for insert to authenticated
with check (
  public.nexo_pode_ver_execucao(execucao_id)
  and alterado_por = public.nexo_usuario_pessoa_id()
);

drop policy if exists "nexo_final_dependencias_all" on public.dependencias;
create policy "nexo_final_dependencias_all"
on public.dependencias for all to authenticated
using (public.nexo_pode_ver_execucao(execucao_id))
with check (public.nexo_pode_ver_execucao(execucao_id));

drop policy if exists "nexo_final_bloqueios_all" on public.bloqueios;
create policy "nexo_final_bloqueios_all"
on public.bloqueios for all to authenticated
using (public.nexo_pode_ver_execucao(execucao_id))
with check (public.nexo_pode_ver_execucao(execucao_id));

drop policy if exists "nexo_final_conferencias_all" on public.conferencias;
create policy "nexo_final_conferencias_all"
on public.conferencias for all to authenticated
using (public.nexo_pode_ver_execucao(execucao_id))
with check (public.nexo_pode_ver_execucao(execucao_id));

drop policy if exists "nexo_final_retrabalhos_all" on public.retrabalhos;
create policy "nexo_final_retrabalhos_all"
on public.retrabalhos for all to authenticated
using (public.nexo_pode_ver_execucao(execucao_id))
with check (public.nexo_pode_ver_execucao(execucao_id));

drop policy if exists "nexo_final_aprovacoes_all" on public.aprovacoes;
create policy "nexo_final_aprovacoes_all"
on public.aprovacoes for all to authenticated
using (public.nexo_pode_ver_execucao(execucao_id))
with check (public.nexo_pode_ver_execucao(execucao_id));

drop policy if exists "nexo_final_evidencias_all" on public.evidencias;
create policy "nexo_final_evidencias_all"
on public.evidencias for all to authenticated
using (public.nexo_pode_ver_execucao(execucao_id))
with check (public.nexo_pode_ver_execucao(execucao_id));

-- ------------------------------------------------------------
-- Conclusão transacional e obrigatória
-- ------------------------------------------------------------

create or replace function public.nexo_concluir_execucao(p_execucao_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_exec public.execucoes%rowtype;
  v_op public.operacoes%rowtype;
  v_agora timestamptz := now();
begin
  if auth.uid() is null then
    raise exception 'Usuário não autenticado.';
  end if;

  if not public.nexo_pode_ver_execucao(p_execucao_id) then
    raise exception 'Você não possui acesso a esta execução.';
  end if;

  select * into v_exec
  from public.execucoes
  where id = p_execucao_id
  for update;

  if not found then
    raise exception 'Execução não encontrada.';
  end if;

  if v_exec.status in ('CONCLUIDA','CANCELADA') then
    raise exception 'A execução já está encerrada.';
  end if;

  select * into v_op
  from public.operacoes
  where id = v_exec.operacao_id;

  if exists (
    select 1 from public.bloqueios
    where execucao_id = p_execucao_id and ativo = true
  ) then
    raise exception 'Existe bloqueio ativo. Resolva o bloqueio antes de concluir.';
  end if;

  if exists (
    select 1 from public.dependencias
    where execucao_id = p_execucao_id and ativo = true
  ) then
    raise exception 'Existe dependência ativa. Finalize a dependência antes de concluir.';
  end if;

  if exists (
    select 1 from public.retrabalhos
    where execucao_id = p_execucao_id
      and status in ('PENDENTE','EM_CORRECAO')
  ) then
    raise exception 'Existe retrabalho pendente. Corrija antes de concluir.';
  end if;

  if v_op.exige_conferencia and not exists (
    select 1 from public.conferencias
    where execucao_id = p_execucao_id and resultado = 'APROVADA'
  ) then
    raise exception 'A operação exige conferência aprovada.';
  end if;

  if v_op.exige_aprovacao and not exists (
    select 1 from public.aprovacoes
    where execucao_id = p_execucao_id and status = 'APROVADA'
  ) then
    raise exception 'A operação exige aprovação.';
  end if;

  if v_op.exige_evidencia and not exists (
    select 1 from public.evidencias
    where execucao_id = p_execucao_id
  ) then
    raise exception 'A operação exige pelo menos uma evidência.';
  end if;

  update public.execucoes
  set
    status = 'CONCLUIDA',
    percentual_conclusao = 100,
    data_inicio = coalesce(data_inicio, v_agora),
    data_conclusao = v_agora,
    updated_at = v_agora
  where id = p_execucao_id;

  insert into public.execucao_status_historico (
    execucao_id,
    status_anterior,
    status_novo,
    alterado_por,
    motivo
  )
  values (
    p_execucao_id,
    v_exec.status,
    'CONCLUIDA',
    public.nexo_usuario_pessoa_id(),
    'Conclusão validada pelo NEXO'
  );

  update public.demandas
  set
    status = 'CONCLUIDA',
    percentual_conclusao = 100,
    data_inicio = coalesce(data_inicio, v_exec.data_inicio, v_agora),
    data_conclusao = v_agora,
    updated_at = v_agora
  where execucao_id = p_execucao_id
    and status <> 'CANCELADA';

  return jsonb_build_object(
    'ok', true,
    'execucao_id', p_execucao_id,
    'status', 'CONCLUIDA'
  );
end
$$;

grant execute on function public.nexo_concluir_execucao(uuid) to authenticated;

-- ------------------------------------------------------------
-- Geração automática das rotinas recorrentes
-- É idempotente: não duplica a mesma recorrência/data.
-- ------------------------------------------------------------

create or replace function public.nexo_gerar_recorrencias()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_empresa uuid := public.nexo_usuario_empresa_id();
  v_resp uuid;
  v_data date := current_date;
  v_prazo timestamptz;
  v_geradas integer := 0;
  v_aplica boolean;
begin
  if auth.uid() is null or v_empresa is null then
    return 0;
  end if;

  for r in
    select
      rec.id as recorrencia_id,
      rec.tipo_recorrencia,
      rec.dia_semana,
      rec.dia_mes,
      rec.data_especifica,
      rec.hora_prevista,
      rec.prazo_minutos,
      rec.sla_minutos,
      o.id as operacao_id,
      o.nome,
      o.prioridade,
      o.tempo_estimado_minutos
    from public.operacao_recorrencias rec
    join public.operacoes o on o.id = rec.operacao_id
    where rec.ativo = true
      and o.ativo = true
      and o.empresa_id = v_empresa
  loop
    v_aplica := false;

    if r.tipo_recorrencia = 'DIARIA' then
      v_aplica := true;
    elsif r.tipo_recorrencia = 'SEMANAL' then
      v_aplica := r.dia_semana = extract(isodow from v_data)::int;
    elsif r.tipo_recorrencia = 'MENSAL' then
      v_aplica := r.dia_mes = extract(day from v_data)::int;
    elsif r.tipo_recorrencia = 'DATA_ESPECIFICA' then
      v_aplica := r.data_especifica = v_data;
    elsif r.tipo_recorrencia = 'ANUAL' and r.data_especifica is not null then
      v_aplica :=
        extract(month from r.data_especifica) = extract(month from v_data)
        and extract(day from r.data_especifica) = extract(day from v_data);
    end if;

    if not v_aplica then
      continue;
    end if;

    if exists (
      select 1 from public.execucoes
      where recorrencia_id = r.recorrencia_id
        and data_referencia = v_data
    ) then
      continue;
    end if;

    select orr.pessoa_id
    into v_resp
    from public.operacao_responsaveis orr
    where orr.operacao_id = r.operacao_id
      and orr.ativo = true
      and orr.papel in ('RESPONSAVEL','EXECUTOR')
    order by
      case when orr.principal then 0 else 1 end,
      case when orr.papel = 'RESPONSAVEL' then 0 else 1 end
    limit 1;

    v_prazo :=
      v_data::timestamp
      + coalesce(r.hora_prevista, time '08:00')
      + make_interval(mins => coalesce(r.prazo_minutos, r.sla_minutos, r.tempo_estimado_minutos, 0));

    insert into public.execucoes (
      operacao_id,
      responsavel_id,
      titulo,
      status,
      prioridade,
      data_prevista,
      prazo_minutos,
      sla_minutos,
      percentual_conclusao,
      recorrencia_id,
      data_referencia
    )
    values (
      r.operacao_id,
      v_resp,
      r.nome,
      'NAO_INICIADA',
      r.prioridade,
      v_prazo,
      r.prazo_minutos,
      r.sla_minutos,
      0,
      r.recorrencia_id,
      v_data
    )
    on conflict do nothing;

    if found then
      v_geradas := v_geradas + 1;
    end if;
  end loop;

  return v_geradas;
end
$$;

grant execute on function public.nexo_gerar_recorrencias() to authenticated;

-- ------------------------------------------------------------
-- Alertas operacionais: atraso, bloqueio, dependência,
-- conferência, aprovação e retrabalho.
-- Não duplica alerta ainda não lido.
-- ------------------------------------------------------------

create or replace function public.nexo_atualizar_alertas()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_empresa uuid := public.nexo_usuario_empresa_id();
  v_total integer := 0;
begin
  if auth.uid() is null or v_empresa is null then
    return 0;
  end if;

  insert into public.alertas (execucao_id, pessoa_id, tipo, titulo, mensagem, prioridade)
  select
    e.id,
    e.responsavel_id,
    'ATRASO',
    'Execução atrasada',
    e.titulo || ' está com o prazo ultrapassado.',
    case when e.prioridade in ('CRITICA','ALTA') then 'ALTA' else 'NORMAL' end
  from public.execucoes e
  join public.operacoes o on o.id = e.operacao_id
  where o.empresa_id = v_empresa
    and e.responsavel_id is not null
    and e.data_prevista < now()
    and e.status not in ('CONCLUIDA','CANCELADA')
    and not exists (
      select 1 from public.alertas a
      where a.execucao_id = e.id
        and a.pessoa_id = e.responsavel_id
        and a.tipo = 'ATRASO'
        and a.lido = false
    );
  get diagnostics v_total = row_count;

  insert into public.alertas (execucao_id, pessoa_id, tipo, titulo, mensagem, prioridade)
  select
    e.id,
    e.responsavel_id,
    'BLOQUEIO',
    'Execução bloqueada',
    coalesce(b.motivo, e.titulo),
    'ALTA'
  from public.bloqueios b
  join public.execucoes e on e.id = b.execucao_id
  join public.operacoes o on o.id = e.operacao_id
  where o.empresa_id = v_empresa
    and b.ativo = true
    and e.responsavel_id is not null
    and not exists (
      select 1 from public.alertas a
      where a.execucao_id = e.id
        and a.pessoa_id = e.responsavel_id
        and a.tipo = 'BLOQUEIO'
        and a.lido = false
    );

  insert into public.alertas (execucao_id, pessoa_id, tipo, titulo, mensagem, prioridade)
  select
    e.id,
    e.responsavel_id,
    'DEPENDENCIA',
    'Dependência aguardando retorno',
    d.motivo,
    case when d.impacto in ('CRITICO','ALTO') then 'ALTA' else 'NORMAL' end
  from public.dependencias d
  join public.execucoes e on e.id = d.execucao_id
  join public.operacoes o on o.id = e.operacao_id
  where o.empresa_id = v_empresa
    and d.ativo = true
    and e.responsavel_id is not null
    and not exists (
      select 1 from public.alertas a
      where a.execucao_id = e.id
        and a.pessoa_id = e.responsavel_id
        and a.tipo = 'DEPENDENCIA'
        and a.lido = false
    );

  insert into public.alertas (execucao_id, pessoa_id, tipo, titulo, mensagem, prioridade)
  select
    c.execucao_id,
    c.conferente_id,
    'CONFERENCIA',
    'Conferência pendente',
    e.titulo,
    'NORMAL'
  from public.conferencias c
  join public.execucoes e on e.id = c.execucao_id
  join public.operacoes o on o.id = e.operacao_id
  where o.empresa_id = v_empresa
    and c.resultado = 'PENDENTE'
    and not exists (
      select 1 from public.alertas a
      where a.execucao_id = c.execucao_id
        and a.pessoa_id = c.conferente_id
        and a.tipo = 'CONFERENCIA'
        and a.lido = false
    );

  insert into public.alertas (execucao_id, pessoa_id, tipo, titulo, mensagem, prioridade)
  select
    a0.execucao_id,
    a0.aprovador_id,
    'APROVACAO',
    'Aprovação pendente',
    e.titulo,
    'NORMAL'
  from public.aprovacoes a0
  join public.execucoes e on e.id = a0.execucao_id
  join public.operacoes o on o.id = e.operacao_id
  where o.empresa_id = v_empresa
    and a0.status = 'PENDENTE'
    and not exists (
      select 1 from public.alertas a
      where a.execucao_id = a0.execucao_id
        and a.pessoa_id = a0.aprovador_id
        and a.tipo = 'APROVACAO'
        and a.lido = false
    );

  insert into public.alertas (execucao_id, pessoa_id, tipo, titulo, mensagem, prioridade)
  select
    r.execucao_id,
    r.responsavel_correcao_id,
    'RETRABALHO',
    'Retrabalho pendente',
    r.motivo,
    'ALTA'
  from public.retrabalhos r
  join public.execucoes e on e.id = r.execucao_id
  join public.operacoes o on o.id = e.operacao_id
  where o.empresa_id = v_empresa
    and r.status in ('PENDENTE','EM_CORRECAO')
    and r.responsavel_correcao_id is not null
    and not exists (
      select 1 from public.alertas a
      where a.execucao_id = r.execucao_id
        and a.pessoa_id = r.responsavel_correcao_id
        and a.tipo = 'RETRABALHO'
        and a.lido = false
    );

  return v_total;
end
$$;

grant execute on function public.nexo_atualizar_alertas() to authenticated;

-- ------------------------------------------------------------
-- Proteção do último ADMIN
-- ------------------------------------------------------------

create or replace function public.nexo_proteger_ultimo_admin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid;
  v_qtd integer;
begin
  select id into v_admin_id from public.perfis where nome = 'ADMIN' limit 1;

  if old.perfil_id = v_admin_id
     and old.ativo = true
     and (new.perfil_id is distinct from v_admin_id or new.ativo = false) then

    select count(*) into v_qtd
    from public.usuarios
    where perfil_id = v_admin_id
      and ativo = true
      and id <> old.id;

    if v_qtd = 0 then
      raise exception 'Não é permitido remover ou desativar o último ADMIN.';
    end if;
  end if;

  return new;
end
$$;

drop trigger if exists trg_nexo_proteger_ultimo_admin on public.usuarios;
create trigger trg_nexo_proteger_ultimo_admin
before update on public.usuarios
for each row execute function public.nexo_proteger_ultimo_admin();

-- ------------------------------------------------------------
-- Encerramento
-- ------------------------------------------------------------

select
  'NEXO FECHAMENTO OPERACIONAL APLICADO' as resultado,
  now() as aplicado_em;
NEXO_SQL

echo
echo "Arquivos atualizados."
echo "SQL gerado em: $APP/supabase_nexo_fechamento.sql"
echo
echo "ATENÇÃO: execute o SQL no Supabase antes do teste final."
echo

npm run build

echo
echo "============================================================"
echo " NEXO - FECHAMENTO OPERACIONAL INSTALADO"
echo " Build concluído."
echo " Próximo: executar supabase_nexo_fechamento.sql no Supabase."
echo "============================================================"
