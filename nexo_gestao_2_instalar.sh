#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/nexo/nexo
mkdir -p src/pages src/lib

cat > src/lib/gestao.ts <<'NEXO_EOF'
export type ExecucaoGestao = {
  id: string
  titulo?: string
  status: string
  prioridade?: string
  data_prevista: string | null
  data_inicio?: string | null
  data_conclusao?: string | null
  responsavel_id: string | null
  operacao_id: string
  percentual_conclusao?: number
}

export type RetrabalhoGestao = {
  id: string
  execucao_id: string
  pessoa_origem_id?: string | null
  responsavel_correcao_id?: string | null
  status: string
}

export type BloqueioGestao = {
  id: string
  execucao_id: string
  ativo: boolean
  motivo?: string | null
  iniciado_em?: string | null
  finalizado_em?: string | null
}

export type DependenciaGestao = {
  id: string
  execucao_id: string
  ativo: boolean
  tipo_dependencia?: string | null
  motivo?: string | null
  impacto?: string | null
  entidade_externa?: string | null
  previsao_retorno?: string | null
  proxima_acao?: string | null
  iniciado_em?: string | null
  finalizado_em?: string | null
}

export type CargaGestao = {
  pessoa_id: string
  percentual_carga: number | null
  tempo_estimado_minutos?: number | null
}

export function estaAtrasada(execucao: ExecucaoGestao) {
  if (!execucao.data_prevista || ['CONCLUIDA', 'CANCELADA'].includes(execucao.status)) return false
  return new Date(execucao.data_prevista).getTime() < Date.now()
}

export function horasEntre(inicio?: string | null, fim?: string | null) {
  if (!inicio) return 0
  const a = new Date(inicio).getTime()
  const b = fim ? new Date(fim).getTime() : Date.now()
  return Math.max(0, (b - a) / 3600000)
}

export function classificacaoScore(score: number) {
  if (score >= 90) return { label: 'Excelente', nivel: 'excelente', emoji: '🟢' }
  if (score >= 80) return { label: 'Muito bom', nivel: 'bom', emoji: '🟢' }
  if (score >= 70) return { label: 'Atenção', nivel: 'atencao', emoji: '🟡' }
  if (score >= 60) return { label: 'Crítico', nivel: 'critico', emoji: '🟠' }
  return { label: 'Muito crítico', nivel: 'muito-critico', emoji: '🔴' }
}

export function scorePessoa(params: {
  pessoaId: string
  execucoes: ExecucaoGestao[]
  retrabalhos: RetrabalhoGestao[]
  bloqueios: BloqueioGestao[]
  dependencias: DependenciaGestao[]
  carga: CargaGestao[]
}) {
  const { pessoaId, execucoes, retrabalhos, bloqueios, dependencias, carga } = params
  const minhas = execucoes.filter((x) => x.responsavel_id === pessoaId)
  const concluidas = minhas.filter((x) => x.status === 'CONCLUIDA')
  const abertas = minhas.filter((x) => !['CONCLUIDA', 'CANCELADA'].includes(x.status))
  const atrasadas = abertas.filter(estaAtrasada)
  const concluidasNoPrazo = concluidas.filter((x) => !x.data_prevista || !x.data_conclusao || new Date(x.data_conclusao) <= new Date(x.data_prevista))

  const ids = new Set(minhas.map((x) => x.id))
  const depsExternas = dependencias.filter((d) => ids.has(d.execucao_id) && d.ativo && ['FORNECEDOR', 'CLIENTE', 'SISTEMA', 'INFORMACAO', 'APROVACAO', 'OUTRO'].includes(d.tipo_dependencia || ''))
  const atrasosComDependencia = atrasadas.filter((x) => depsExternas.some((d) => d.execucao_id === x.id)).length
  const atrasosResponsabilidade = Math.max(0, atrasadas.length - atrasosComDependencia)

  const retrabalhoOrigem = retrabalhos.filter((r) => r.pessoa_origem_id === pessoaId && r.status !== 'CANCELADO').length
  const bloqueiosAtivos = bloqueios.filter((b) => ids.has(b.execucao_id) && b.ativo).length
  const cargaTotal = carga.filter((c) => c.pessoa_id === pessoaId).reduce((s, c) => s + (Number(c.percentual_carga) || 0), 0)

  const prazoBase = concluidas.length ? (concluidasNoPrazo.length / concluidas.length) : (minhas.length ? Math.max(0, 1 - atrasosResponsabilidade / Math.max(1, abertas.length)) : 1)
  const prazo = Math.round(25 * Math.max(0, Math.min(1, prazoBase)))

  const qualidadeRatio = minhas.length ? Math.max(0, 1 - retrabalhoOrigem / Math.max(1, minhas.length)) : 1
  const qualidade = Math.round(20 * qualidadeRatio)

  const sla = Math.round(15 * Math.max(0, Math.min(1, prazoBase)))

  const concluidasPeso = concluidas.length
  const cargaIdeal = cargaTotal <= 0 ? 75 : cargaTotal
  const produtividadeRatio = Math.min(1, concluidasPeso / Math.max(1, concluidasPeso + abertas.length * 0.35))
  const produtividade = Math.round(15 * Math.max(0.55, produtividadeRatio))

  let cargaScore = 10
  if (cargaIdeal > 120) cargaScore = 5
  else if (cargaIdeal > 100) cargaScore = 7
  else if (cargaIdeal < 45 && minhas.length > 0) cargaScore = 8

  const bloqueioScore = Math.max(0, 5 - Math.min(5, bloqueiosAtivos))
  const retrabalhoScore = Math.max(0, 5 - Math.min(5, retrabalhoOrigem * 2))
  const regularidade = atrasosResponsabilidade === 0 ? 5 : Math.max(0, 5 - atrasosResponsabilidade)

  const score = Math.max(0, Math.min(100, prazo + qualidade + sla + produtividade + cargaScore + bloqueioScore + retrabalhoScore + regularidade))

  const impactos: { texto: string; peso: number }[] = []
  if (atrasosResponsabilidade) impactos.push({ texto: `${atrasosResponsabilidade} atraso(s) sob responsabilidade direta`, peso: atrasosResponsabilidade * 5 })
  if (retrabalhoOrigem) impactos.push({ texto: `${retrabalhoOrigem} retrabalho(s) com origem na execução`, peso: retrabalhoOrigem * 6 })
  if (cargaTotal > 100) impactos.push({ texto: `sobrecarga de ${Math.round(cargaTotal)}%`, peso: Math.round(cargaTotal - 100) })
  if (bloqueiosAtivos) impactos.push({ texto: `${bloqueiosAtivos} bloqueio(s) ativo(s)`, peso: bloqueiosAtivos * 3 })
  if (atrasosComDependencia) impactos.push({ texto: `${atrasosComDependencia} atraso(s) associados a dependência externa`, peso: 1 })
  impactos.sort((a, b) => b.peso - a.peso)

  return {
    score,
    classificacao: classificacaoScore(score),
    prazo,
    qualidade,
    sla,
    produtividade,
    cargaScore,
    bloqueioScore,
    retrabalhoScore,
    regularidade,
    cargaTotal: Math.round(cargaTotal),
    abertas: abertas.length,
    concluidas: concluidas.length,
    atrasadas: atrasadas.length,
    atrasosResponsabilidade,
    atrasosComDependencia,
    retrabalhoOrigem,
    bloqueiosAtivos,
    principalImpacto: impactos[0]?.texto || 'Sem impacto relevante identificado',
  }
}
NEXO_EOF

cat > src/pages/IndicadoresPage.tsx <<'NEXO_EOF'
import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario } from '../types'
import {
  classificacaoScore,
  estaAtrasada,
  horasEntre,
  scorePessoa,
  type BloqueioGestao,
  type CargaGestao,
  type DependenciaGestao,
  type ExecucaoGestao,
  type RetrabalhoGestao,
} from '../lib/gestao'

type Props = { usuario: DadosUsuario }
type Pessoa = { id: string; nome: string; setor_id: string | null; setor?: { nome: string } | null; cargo?: { nome: string } | null }
type Setor = { id: string; nome: string }
type Processo = { id: string; nome: string; setor_id: string }
type Operacao = { id: string; nome: string; setor_id: string; processo_id: string | null }

function normalizarRelacao<T>(valor: T | T[] | null | undefined): T | null {
  if (!valor) return null
  return Array.isArray(valor) ? valor[0] || null : valor
}

export default function IndicadoresPage({ usuario }: Props) {
  const [execucoes, setExecucoes] = useState<ExecucaoGestao[]>([])
  const [retrabalhos, setRetrabalhos] = useState<RetrabalhoGestao[]>([])
  const [bloqueios, setBloqueios] = useState<BloqueioGestao[]>([])
  const [dependencias, setDependencias] = useState<DependenciaGestao[]>([])
  const [carga, setCarga] = useState<CargaGestao[]>([])
  const [pessoas, setPessoas] = useState<Pessoa[]>([])
  const [setores, setSetores] = useState<Setor[]>([])
  const [processos, setProcessos] = useState<Processo[]>([])
  const [operacoes, setOperacoes] = useState<Operacao[]>([])
  const [mensagem, setMensagem] = useState('')
  const [periodo, setPeriodo] = useState(30)
  const [setorFiltro, setSetorFiltro] = useState('')

  useEffect(() => {
    async function carregar() {
      try {
        setMensagem('')
        const [e, r, b, d, c, p, s, pr, o] = await Promise.all([
          supabase.from('execucoes').select('id,titulo,status,prioridade,data_prevista,data_inicio,data_conclusao,responsavel_id,operacao_id,percentual_conclusao,created_at'),
          supabase.from('retrabalhos').select('id,execucao_id,pessoa_origem_id,responsavel_correcao_id,status'),
          supabase.from('bloqueios').select('id,execucao_id,ativo,motivo,iniciado_em,finalizado_em'),
          supabase.from('dependencias').select('id,execucao_id,ativo,tipo_dependencia,motivo,impacto,entidade_externa,previsao_retorno,proxima_acao,iniciado_em,finalizado_em'),
          supabase.from('carga_trabalho').select('pessoa_id,percentual_carga,tempo_estimado_minutos'),
          supabase.from('pessoas').select('id,nome,setor_id,setor:setores(nome),cargo:cargos(nome)').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('nome'),
          supabase.from('setores').select('id,nome').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('nome'),
          supabase.from('processos').select('id,nome,setor_id').eq('empresa_id', usuario.empresaId).eq('ativo', true),
          supabase.from('operacoes').select('id,nome,setor_id,processo_id').eq('empresa_id', usuario.empresaId).eq('ativo', true),
        ])
        for (const x of [e, r, b, d, c, p, s, pr, o]) if (x.error) throw x.error
        setExecucoes((e.data || []) as unknown as ExecucaoGestao[])
        setRetrabalhos((r.data || []) as unknown as RetrabalhoGestao[])
        setBloqueios((b.data || []) as unknown as BloqueioGestao[])
        setDependencias((d.data || []) as unknown as DependenciaGestao[])
        setCarga((c.data || []) as unknown as CargaGestao[])
        setPessoas((p.data || []).map((item: any) => ({ ...item, setor: normalizarRelacao(item.setor), cargo: normalizarRelacao(item.cargo) })) as Pessoa[])
        setSetores((s.data || []) as Setor[])
        setProcessos((pr.data || []) as Processo[])
        setOperacoes((o.data || []) as Operacao[])
      } catch (error: any) {
        console.error(error)
        setMensagem(error?.message || 'Erro ao carregar indicadores.')
      }
    }
    carregar()
  }, [usuario.empresaId])

  const limite = useMemo(() => Date.now() - periodo * 86400000, [periodo])

  const operacaoMap = useMemo(() => new Map(operacoes.map((x) => [x.id, x])), [operacoes])
  const processoMap = useMemo(() => new Map(processos.map((x) => [x.id, x])), [processos])

  const execFiltradas = useMemo(() => execucoes.filter((x: any) => {
    const operacao = operacaoMap.get(x.operacao_id)
    const setorOk = !setorFiltro || operacao?.setor_id === setorFiltro
    const dataRef = x.data_conclusao || x.data_inicio || x.created_at || x.data_prevista
    const periodoOk = !dataRef || new Date(dataRef).getTime() >= limite || !['CONCLUIDA', 'CANCELADA'].includes(x.status)
    return setorOk && periodoOk
  }), [execucoes, operacaoMap, setorFiltro, limite])

  const idsFiltrados = useMemo(() => new Set(execFiltradas.map((x) => x.id)), [execFiltradas])
  const retrFiltrados = useMemo(() => retrabalhos.filter((x) => idsFiltrados.has(x.execucao_id)), [retrabalhos, idsFiltrados])
  const bloqFiltrados = useMemo(() => bloqueios.filter((x) => idsFiltrados.has(x.execucao_id)), [bloqueios, idsFiltrados])
  const depFiltradas = useMemo(() => dependencias.filter((x) => idsFiltrados.has(x.execucao_id)), [dependencias, idsFiltrados])

  const kpis = useMemo(() => {
    const abertas = execFiltradas.filter((x) => !['CONCLUIDA', 'CANCELADA'].includes(x.status))
    const concluidas = execFiltradas.filter((x) => x.status === 'CONCLUIDA')
    const noPrazo = concluidas.filter((x) => !x.data_prevista || !x.data_conclusao || new Date(x.data_conclusao) <= new Date(x.data_prevista)).length
    const atrasadas = abertas.filter(estaAtrasada).length
    const tempoMedioLista = concluidas.filter((x) => x.data_inicio && x.data_conclusao).map((x) => horasEntre(x.data_inicio, x.data_conclusao))
    const tempoMedio = tempoMedioLista.length ? tempoMedioLista.reduce((a, b) => a + b, 0) / tempoMedioLista.length : 0
    const taxaPrazo = concluidas.length ? (noPrazo / concluidas.length) * 100 : 100
    const taxaAtraso = abertas.length ? (atrasadas / abertas.length) * 100 : 0
    const taxaRetrabalho = execFiltradas.length ? (retrFiltrados.length / execFiltradas.length) * 100 : 0
    const taxaBloqueio = abertas.length ? (bloqFiltrados.filter((x) => x.ativo).length / abertas.length) * 100 : 0
    const saude = Math.round(Math.max(0, Math.min(100, taxaPrazo * 0.45 + (100 - taxaAtraso) * 0.25 + (100 - taxaRetrabalho) * 0.2 + (100 - taxaBloqueio) * 0.1)))
    return {
      abertas: abertas.length,
      atrasadas,
      bloqueiosAtivos: bloqFiltrados.filter((x) => x.ativo).length,
      dependenciasAtivas: depFiltradas.filter((x) => x.ativo).length,
      noPrazo: Math.round(taxaPrazo),
      retrabalho: retrFiltrados.length,
      tempoMedio: Math.round(tempoMedio * 10) / 10,
      saude,
      classificacao: classificacaoScore(saude),
    }
  }, [execFiltradas, retrFiltrados, bloqFiltrados, depFiltradas])

  const porPessoa = useMemo(() => pessoas.map((pessoa) => ({
    ...pessoa,
    ...scorePessoa({ pessoaId: pessoa.id, execucoes: execFiltradas, retrabalhos: retrFiltrados, bloqueios: bloqFiltrados, dependencias: depFiltradas, carga }),
  })).filter((x) => x.abertas || x.concluidas || x.cargaTotal).sort((a, b) => b.score - a.score), [pessoas, execFiltradas, retrFiltrados, bloqFiltrados, depFiltradas, carga])

  const porSetor = useMemo(() => setores.map((setor) => {
    const ops = operacoes.filter((o) => o.setor_id === setor.id)
    const idsOps = new Set(ops.map((o) => o.id))
    const ex = execFiltradas.filter((x) => idsOps.has(x.operacao_id))
    const pessoasSetor = porPessoa.filter((p) => p.setor_id === setor.id)
    const scoreEquipe = pessoasSetor.length ? Math.round(pessoasSetor.reduce((s, p) => s + p.score, 0) / pessoasSetor.length) : 100
    const abertas = ex.filter((x) => !['CONCLUIDA', 'CANCELADA'].includes(x.status))
    const atrasadas = abertas.filter(estaAtrasada).length
    const bloqueadas = abertas.filter((x) => x.status === 'BLOQUEADA').length
    const retrabalho = retrFiltrados.filter((r) => ex.some((x) => x.id === r.execucao_id)).length
    const penalidade = Math.min(45, atrasadas * 6 + bloqueadas * 5 + retrabalho * 4)
    const saude = Math.round(Math.max(0, Math.min(100, scoreEquipe * 0.65 + (100 - penalidade) * 0.35)))
    return { ...setor, abertas: abertas.length, atrasadas, bloqueadas, retrabalho, saude, classificacao: classificacaoScore(saude) }
  }).filter((x) => x.abertas || x.atrasadas || x.retrabalho || porPessoa.some((p) => p.setor_id === x.id)).sort((a, b) => a.saude - b.saude), [setores, operacoes, execFiltradas, retrFiltrados, porPessoa])

  const causas = useMemo(() => {
    const mapa = new Map<string, number>()
    for (const d of depFiltradas.filter((x) => x.ativo)) {
      const chave = d.tipo_dependencia || 'OUTRO'
      mapa.set(chave, (mapa.get(chave) || 0) + 1)
    }
    for (const b of bloqFiltrados.filter((x) => x.ativo)) mapa.set('BLOQUEIO', (mapa.get('BLOQUEIO') || 0) + 1)
    if (retrFiltrados.length) mapa.set('RETRABALHO', retrFiltrados.length)
    return [...mapa.entries()].map(([causa, quantidade]) => ({ causa, quantidade })).sort((a, b) => b.quantidade - a.quantidade)
  }, [depFiltradas, bloqFiltrados, retrFiltrados])

  const maxProblema = Math.max(1, ...porSetor.map((x) => x.atrasadas + x.bloqueadas + x.retrabalho))
  const maxCausa = Math.max(1, ...causas.map((x) => x.quantidade))

  const problemasCriticos = useMemo(() => execFiltradas
    .filter((x) => estaAtrasada(x) || x.status === 'BLOQUEADA' || x.status.startsWith('AGUARDANDO'))
    .map((x) => {
      const op = operacaoMap.get(x.operacao_id)
      const processo = op?.processo_id ? processoMap.get(op.processo_id) : null
      const resp = pessoas.find((p) => p.id === x.responsavel_id)
      const bloqueio = bloqFiltrados.find((b) => b.execucao_id === x.id && b.ativo)
      const dep = depFiltradas.find((d) => d.execucao_id === x.id && d.ativo)
      const gravidade = x.status === 'BLOQUEADA' ? 4 : estaAtrasada(x) ? 3 : x.status.startsWith('AGUARDANDO') ? 2 : 1
      return {
        ...x,
        gravidade,
        setor: setores.find((s) => s.id === op?.setor_id)?.nome || '-',
        processo: processo?.nome || '-',
        responsavel: resp?.nome || 'Não definido',
        motivo: bloqueio?.motivo || dep?.motivo || (estaAtrasada(x) ? 'Prazo ultrapassado' : x.status.replaceAll('_', ' ')),
        proximaAcao: dep?.proxima_acao || 'Abrir execução e definir próxima ação.',
      }
    }).sort((a, b) => b.gravidade - a.gravidade).slice(0, 8), [execFiltradas, operacaoMap, processoMap, pessoas, bloqFiltrados, depFiltradas, setores])

  return (
    <>
      <header className="topbar"><div><h1>Indicadores</h1><p>Saúde operacional, problemas, desempenho e causas.</p></div><div className="topbar-user">{usuario.nome}</div></header>
      {mensagem && <div className="system-message">{mensagem}</div>}

      <section className="nexo-filter-bar">
        <div><label>Período</label><select value={periodo} onChange={(e) => setPeriodo(Number(e.target.value))}><option value={7}>7 dias</option><option value={30}>30 dias</option><option value={90}>90 dias</option><option value={180}>180 dias</option></select></div>
        <div><label>Setor</label><select value={setorFiltro} onChange={(e) => setSetorFiltro(e.target.value)}><option value="">Todos</option>{setores.map((s) => <option key={s.id} value={s.id}>{s.nome}</option>)}</select></div>
      </section>

      <section className="nexo-health-hero">
        <div><span>Saúde operacional</span><strong>{kpis.saude}</strong><small>{kpis.classificacao.emoji} {kpis.classificacao.label}</small></div>
        <div className="nexo-health-copy"><h2>{kpis.saude >= 80 ? 'Operação sob controle' : kpis.saude >= 70 ? 'Existem pontos de atenção' : 'A operação exige ação gerencial'}</h2><p>O índice combina prazo, atraso, retrabalho e bloqueios. Quanto menor o valor, maior a necessidade de intervenção.</p></div>
      </section>

      <section className="cards-grid nexo-kpi-grid">
        <div className="status-card"><span className="card-label">Em aberto</span><strong className="card-value">{kpis.abertas}</strong></div>
        <div className="status-card"><span className="card-label">Atrasadas</span><strong className="card-value">{kpis.atrasadas}</strong></div>
        <div className="status-card"><span className="card-label">Concluídas no prazo</span><strong className="card-value">{kpis.noPrazo}%</strong></div>
        <div className="status-card"><span className="card-label">Retrabalhos</span><strong className="card-value">{kpis.retrabalho}</strong></div>
        <div className="status-card"><span className="card-label">Bloqueios ativos</span><strong className="card-value">{kpis.bloqueiosAtivos}</strong></div>
        <div className="status-card"><span className="card-label">Dependências ativas</span><strong className="card-value">{kpis.dependenciasAtivas}</strong></div>
        <div className="status-card"><span className="card-label">Tempo médio</span><strong className="card-value">{kpis.tempoMedio}h</strong></div>
      </section>

      <section className="panel">
        <div className="panel-header"><h3>Onde precisamos agir agora?</h3><p>Problemas organizados por gravidade, com causa e próxima ação.</p></div>
        <div className="nexo-problem-list">
          {problemasCriticos.length === 0 ? <div className="empty-state">Nenhum problema crítico no período.</div> : problemasCriticos.map((p) => (
            <div className={`nexo-problem-card severity-${p.gravidade}`} key={p.id}>
              <div className="nexo-problem-icon">{p.gravidade >= 4 ? '🔴' : p.gravidade === 3 ? '🟠' : '🟡'}</div>
              <div className="nexo-problem-main"><strong>{p.titulo}</strong><span>{p.setor} • {p.processo}</span><p><b>Motivo:</b> {p.motivo}</p><p><b>Responsável:</b> {p.responsavel}</p><p><b>Próxima ação:</b> {p.proximaAcao}</p></div>
              <div className="nexo-problem-status">{p.status.replaceAll('_', ' ')}</div>
            </div>
          ))}
        </div>
      </section>

      <section className="nexo-two-columns">
        <div className="panel">
          <div className="panel-header"><h3>Problemas por setor</h3><p>Atrasos + bloqueios + retrabalho.</p></div>
          <div className="nexo-bars">
            {porSetor.map((s) => {
              const total = s.atrasadas + s.bloqueadas + s.retrabalho
              return <div className="nexo-bar-row" key={s.id}><div className="nexo-bar-label"><strong>{s.nome}</strong><span>{total}</span></div><div className="nexo-bar-track"><div className="nexo-bar-fill" style={{ width: `${Math.max(4, total / maxProblema * 100)}%` }} /></div><small>{s.atrasadas} atrasadas • {s.bloqueadas} bloqueadas • {s.retrabalho} retrabalho</small></div>
            })}
          </div>
        </div>

        <div className="panel">
          <div className="panel-header"><h3>Principais causas</h3><p>O que está interrompendo ou atrasando o fluxo.</p></div>
          <div className="nexo-bars">
            {causas.length === 0 ? <div className="empty-state">Sem causas registradas.</div> : causas.map((c) => <div className="nexo-bar-row" key={c.causa}><div className="nexo-bar-label"><strong>{c.causa.replaceAll('_', ' ')}</strong><span>{c.quantidade}</span></div><div className="nexo-bar-track"><div className="nexo-bar-fill" style={{ width: `${Math.max(4, c.quantidade / maxCausa * 100)}%` }} /></div></div>)}
          </div>
        </div>
      </section>

      <section className="panel">
        <div className="panel-header"><h3>Saúde por setor</h3><p>Leitura hierárquica da operação.</p></div>
        <div className="nexo-score-grid">
          {porSetor.map((s) => <div className={`nexo-score-card score-${s.classificacao.nivel}`} key={s.id}><div><span>{s.classificacao.emoji}</span><strong>{s.saude}</strong></div><h4>{s.nome}</h4><p>{s.classificacao.label}</p><small>{s.abertas} abertas • {s.atrasadas} atrasadas • {s.bloqueadas} bloqueadas</small></div>)}
        </div>
      </section>

      <section className="panel">
        <div className="panel-header"><h3>Score NEXO por colaborador</h3><p>Prazo, qualidade, produtividade, carga, bloqueios e regularidade.</p></div>
        <div className="table-wrapper"><table className="operations-table"><thead><tr><th>Posição</th><th>Colaborador</th><th>Setor / Cargo</th><th>Score</th><th>Carga</th><th>Abertas</th><th>Atrasadas</th><th>Principal impacto</th></tr></thead><tbody>{porPessoa.map((p, i) => <tr key={p.id}><td>#{i + 1}</td><td><strong>{p.nome}</strong></td><td>{p.setor?.nome || '-'} / {p.cargo?.nome || '-'}</td><td><span className={`nexo-score-pill score-${p.classificacao.nivel}`}>{p.classificacao.emoji} {p.score}</span></td><td>{p.cargaTotal}%</td><td>{p.abertas}</td><td>{p.atrasadas}</td><td>{p.principalImpacto}</td></tr>)}</tbody></table></div>
      </section>
    </>
  )
}
NEXO_EOF

cat > src/pages/PessoasGeralPage.tsx <<'NEXO_EOF'
import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario } from '../types'
import { scorePessoa, type BloqueioGestao, type CargaGestao, type DependenciaGestao, type ExecucaoGestao, type RetrabalhoGestao } from '../lib/gestao'

type Props = { usuario: DadosUsuario }
type Pessoa = { id: string; nome: string; email: string | null; setor_id: string | null; setor?: { nome: string } | null; cargo?: { nome: string } | null }
type Demanda = { id: string; responsavel_id: string | null; status: string; data_prevista: string | null }
type Resp = { pessoa_id: string; operacao_id: string; papel: string; ativo: boolean }

function normalizarRelacao<T>(valor: T | T[] | null | undefined): T | null { if (!valor) return null; return Array.isArray(valor) ? valor[0] || null : valor }

export default function PessoasGeralPage({ usuario }: Props) {
  const [pessoas, setPessoas] = useState<Pessoa[]>([])
  const [execucoes, setExecucoes] = useState<ExecucaoGestao[]>([])
  const [demandas, setDemandas] = useState<Demanda[]>([])
  const [carga, setCarga] = useState<CargaGestao[]>([])
  const [responsabilidades, setResponsabilidades] = useState<Resp[]>([])
  const [retrabalhos, setRetrabalhos] = useState<RetrabalhoGestao[]>([])
  const [bloqueios, setBloqueios] = useState<BloqueioGestao[]>([])
  const [dependencias, setDependencias] = useState<DependenciaGestao[]>([])
  const [mensagem, setMensagem] = useState('')
  const [selecionada, setSelecionada] = useState<string>('')

  useEffect(() => {
    async function carregar() {
      try {
        const [p, e, d, c, r, rt, b, dp] = await Promise.all([
          supabase.from('pessoas').select('id,nome,email,setor_id,setor:setores(nome),cargo:cargos(nome)').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('nome'),
          supabase.from('execucoes').select('id,titulo,status,prioridade,data_prevista,data_inicio,data_conclusao,responsavel_id,operacao_id,percentual_conclusao'),
          supabase.from('demandas').select('id,responsavel_id,status,data_prevista').eq('empresa_id', usuario.empresaId),
          supabase.from('carga_trabalho').select('pessoa_id,tempo_estimado_minutos,percentual_carga'),
          supabase.from('operacao_responsaveis').select('pessoa_id,operacao_id,papel,ativo').eq('ativo', true),
          supabase.from('retrabalhos').select('id,execucao_id,pessoa_origem_id,responsavel_correcao_id,status'),
          supabase.from('bloqueios').select('id,execucao_id,ativo,motivo,iniciado_em,finalizado_em'),
          supabase.from('dependencias').select('id,execucao_id,ativo,tipo_dependencia,motivo,impacto,entidade_externa,previsao_retorno,proxima_acao,iniciado_em,finalizado_em'),
        ])
        for (const x of [p, e, d, c, r, rt, b, dp]) if (x.error) throw x.error
        setPessoas((p.data || []).map((item: any) => ({ ...item, setor: normalizarRelacao(item.setor), cargo: normalizarRelacao(item.cargo) })) as Pessoa[])
        setExecucoes((e.data || []) as unknown as ExecucaoGestao[])
        setDemandas((d.data || []) as Demanda[])
        setCarga((c.data || []) as unknown as CargaGestao[])
        setResponsabilidades((r.data || []) as Resp[])
        setRetrabalhos((rt.data || []) as unknown as RetrabalhoGestao[])
        setBloqueios((b.data || []) as unknown as BloqueioGestao[])
        setDependencias((dp.data || []) as unknown as DependenciaGestao[])
      } catch (error: any) {
        console.error(error); setMensagem(error?.message || 'Erro ao carregar pessoas.')
      }
    }
    carregar()
  }, [usuario.empresaId])

  const linhas = useMemo(() => pessoas.map((pessoa) => {
    const dem = demandas.filter((x) => x.responsavel_id === pessoa.id && !['CONCLUIDA', 'CANCELADA'].includes(x.status))
    const respons = responsabilidades.filter((x) => x.pessoa_id === pessoa.id)
    return { ...pessoa, demandas: dem.length, responsabilidades: respons.length, ...scorePessoa({ pessoaId: pessoa.id, execucoes, retrabalhos, bloqueios, dependencias, carga }) }
  }).sort((a, b) => b.score - a.score), [pessoas, demandas, responsabilidades, execucoes, retrabalhos, bloqueios, dependencias, carga])

  const atual = linhas.find((x) => x.id === selecionada)

  return (
    <>
      <header className="topbar"><div><h1>Pessoas</h1><p>Desempenho, carga, responsabilidades e contexto operacional.</p></div><div className="topbar-user">{usuario.nome}</div></header>
      {mensagem && <div className="system-message">{mensagem}</div>}
      <section className="panel">
        <div className="panel-header"><h3>Equipe</h3><p>A pontuação considera resultado e contexto; dependências externas não são tratadas como falha individual.</p></div>
        <div className="table-wrapper"><table className="operations-table"><thead><tr><th>Pessoa</th><th>Setor / Cargo</th><th>Score</th><th>Carga</th><th>Responsabilidades</th><th>Abertas</th><th>Atrasadas</th><th>Demandas</th><th></th></tr></thead><tbody>{linhas.map((item) => <tr key={item.id}><td><strong>{item.nome}</strong><div className="nexo-muted">{item.email || ''}</div></td><td>{item.setor?.nome || '-'} / {item.cargo?.nome || '-'}</td><td><span className={`nexo-score-pill score-${item.classificacao.nivel}`}>{item.classificacao.emoji} {item.score}</span></td><td>{item.cargaTotal}%</td><td>{item.responsabilidades}</td><td>{item.abertas}</td><td>{item.atrasadas}</td><td>{item.demandas}</td><td><button className="table-action-button" onClick={() => setSelecionada(item.id)}>Analisar</button></td></tr>)}</tbody></table></div>
      </section>

      {atual && <section className="panel"><div className="panel-header"><h3>{atual.nome}</h3><p>{atual.classificacao.emoji} Score {atual.score} — {atual.classificacao.label}</p></div><div className="nexo-person-detail"><div className="nexo-score-big"><strong>{atual.score}</strong><span>Score NEXO</span></div><div className="nexo-metric-list"><div><span>Prazo</span><strong>{atual.prazo}/25</strong></div><div><span>Qualidade</span><strong>{atual.qualidade}/20</strong></div><div><span>SLA</span><strong>{atual.sla}/15</strong></div><div><span>Produtividade</span><strong>{atual.produtividade}/15</strong></div><div><span>Carga equilibrada</span><strong>{atual.cargaScore}/10</strong></div><div><span>Regularidade</span><strong>{atual.regularidade}/5</strong></div></div><div className="nexo-insight-box"><h4>Leitura do desempenho</h4><p><strong>Principal impacto:</strong> {atual.principalImpacto}</p><p>{atual.cargaTotal > 100 ? 'A pessoa está acima da capacidade planejada. Antes de interpretar atrasos como baixa performance, redistribua carga.' : atual.atrasosComDependencia > 0 ? 'Existem atrasos ligados a dependências externas; eles devem ser tratados como problema de fluxo, não como falha individual.' : atual.score >= 80 ? 'Desempenho consistente no período analisado.' : 'Existem sinais que merecem acompanhamento do líder.'}</p><p><b>Atrasos externos:</b> {atual.atrasosComDependencia} • <b>Retrabalho de origem:</b> {atual.retrabalhoOrigem} • <b>Bloqueios ativos:</b> {atual.bloqueiosAtivos}</p></div></div></section>}
    </>
  )
}
NEXO_EOF

cat > src/pages/CentralPage.tsx <<'NEXO_EOF'
import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario, Pagina } from '../types'
import { classificacaoScore, estaAtrasada, type ExecucaoGestao, type BloqueioGestao, type DependenciaGestao, type RetrabalhoGestao } from '../lib/gestao'

type Props = { usuario: DadosUsuario; navegar: (pagina: Pagina) => void }
type Operacao = { id: string; nome: string; setor_id: string; processo_id: string | null }
type Setor = { id: string; nome: string }
type Processo = { id: string; nome: string }
type Pessoa = { id: string; nome: string }
type Demanda = { id: string; titulo: string; status: string; prioridade: string; data_prevista: string | null; percentual_conclusao: number; solicitante_id: string; responsavel_id: string | null }

export default function CentralPage({ usuario, navegar }: Props) {
  const [execucoes, setExecucoes] = useState<ExecucaoGestao[]>([])
  const [demandas, setDemandas] = useState<Demanda[]>([])
  const [bloqueios, setBloqueios] = useState<BloqueioGestao[]>([])
  const [dependencias, setDependencias] = useState<DependenciaGestao[]>([])
  const [retrabalhos, setRetrabalhos] = useState<RetrabalhoGestao[]>([])
  const [operacoes, setOperacoes] = useState<Operacao[]>([])
  const [setores, setSetores] = useState<Setor[]>([])
  const [processos, setProcessos] = useState<Processo[]>([])
  const [pessoas, setPessoas] = useState<Pessoa[]>([])
  const [mensagem, setMensagem] = useState('')

  useEffect(() => {
    async function carregar() {
      try {
        const [e, d, b, dp, rt, o, s, pr, p] = await Promise.all([
          supabase.from('execucoes').select('id,titulo,status,prioridade,data_prevista,data_inicio,data_conclusao,responsavel_id,operacao_id,percentual_conclusao'),
          supabase.from('demandas').select('id,titulo,status,prioridade,data_prevista,percentual_conclusao,solicitante_id,responsavel_id').eq('empresa_id', usuario.empresaId).neq('status','CONCLUIDA').neq('status','CANCELADA'),
          supabase.from('bloqueios').select('id,execucao_id,ativo,motivo,iniciado_em,finalizado_em'),
          supabase.from('dependencias').select('id,execucao_id,ativo,tipo_dependencia,motivo,impacto,entidade_externa,previsao_retorno,proxima_acao,iniciado_em,finalizado_em'),
          supabase.from('retrabalhos').select('id,execucao_id,pessoa_origem_id,responsavel_correcao_id,status'),
          supabase.from('operacoes').select('id,nome,setor_id,processo_id').eq('empresa_id', usuario.empresaId).eq('ativo', true),
          supabase.from('setores').select('id,nome').eq('empresa_id', usuario.empresaId).eq('ativo', true),
          supabase.from('processos').select('id,nome').eq('empresa_id', usuario.empresaId).eq('ativo', true),
          supabase.from('pessoas').select('id,nome').eq('empresa_id', usuario.empresaId).eq('ativo', true),
        ])
        for (const x of [e, d, b, dp, rt, o, s, pr, p]) if (x.error) throw x.error
        setExecucoes((e.data || []) as unknown as ExecucaoGestao[])
        setDemandas((d.data || []) as Demanda[])
        setBloqueios((b.data || []) as unknown as BloqueioGestao[])
        setDependencias((dp.data || []) as unknown as DependenciaGestao[])
        setRetrabalhos((rt.data || []) as unknown as RetrabalhoGestao[])
        setOperacoes((o.data || []) as Operacao[])
        setSetores((s.data || []) as Setor[])
        setProcessos((pr.data || []) as Processo[])
        setPessoas((p.data || []) as Pessoa[])
      } catch (error: any) { console.error(error); setMensagem(error?.message || 'Erro ao carregar a central.') }
    }
    carregar()
  }, [usuario.empresaId])

  const minhas = useMemo(() => execucoes.filter((x) => x.responsavel_id === usuario.pessoaId && !['CONCLUIDA','CANCELADA'].includes(x.status)), [execucoes, usuario.pessoaId])
  const minhasDemandas = useMemo(() => demandas.filter((x) => x.responsavel_id === usuario.pessoaId || x.solicitante_id === usuario.pessoaId), [demandas, usuario.pessoaId])

  const saude = useMemo(() => {
    const abertas = execucoes.filter((x) => !['CONCLUIDA','CANCELADA'].includes(x.status))
    const concluidas = execucoes.filter((x) => x.status === 'CONCLUIDA')
    const noPrazo = concluidas.filter((x) => !x.data_prevista || !x.data_conclusao || new Date(x.data_conclusao) <= new Date(x.data_prevista)).length
    const atraso = abertas.filter(estaAtrasada).length
    const prazo = concluidas.length ? noPrazo / concluidas.length * 100 : 100
    const atrasoTaxa = abertas.length ? atraso / abertas.length * 100 : 0
    const retr = execucoes.length ? retrabalhos.length / execucoes.length * 100 : 0
    const bloq = abertas.length ? bloqueios.filter((x) => x.ativo).length / abertas.length * 100 : 0
    return Math.round(Math.max(0, Math.min(100, prazo * .45 + (100-atrasoTaxa)*.25 + (100-retr)*.2 + (100-bloq)*.1)))
  }, [execucoes, retrabalhos, bloqueios])

  const problemas = useMemo(() => execucoes.filter((x) => !['CONCLUIDA','CANCELADA'].includes(x.status) && (estaAtrasada(x) || x.status === 'BLOQUEADA' || x.status.startsWith('AGUARDANDO'))).map((x) => {
    const op = operacoes.find((o) => o.id === x.operacao_id)
    const setor = setores.find((s) => s.id === op?.setor_id)?.nome || '-'
    const processo = processos.find((p) => p.id === op?.processo_id)?.nome || '-'
    const pessoa = pessoas.find((p) => p.id === x.responsavel_id)?.nome || 'Não definido'
    const b = bloqueios.find((b) => b.execucao_id === x.id && b.ativo)
    const d = dependencias.find((d) => d.execucao_id === x.id && d.ativo)
    const gravidade = x.status === 'BLOQUEADA' ? 4 : estaAtrasada(x) ? 3 : 2
    return { ...x, setor, processo, pessoa, motivo: b?.motivo || d?.motivo || (estaAtrasada(x) ? 'Prazo ultrapassado' : x.status.replaceAll('_',' ')), proximaAcao: d?.proxima_acao || 'Abrir a execução e tratar a pendência.', gravidade }
  }).sort((a,b) => b.gravidade - a.gravidade).slice(0,5), [execucoes, operacoes, setores, processos, pessoas, bloqueios, dependencias])

  const cls = classificacaoScore(saude)
  const resumo = { atividades: minhas.length, demandas: minhasDemandas.length, atrasadas: minhas.filter(estaAtrasada).length, bloqueadas: minhas.filter((x)=>x.status==='BLOQUEADA').length, aguardando: minhas.filter((x)=>x.status.startsWith('AGUARDANDO')).length }

  return <>
    <header className="topbar"><div><h1>Minha Central</h1><p>Leitura rápida do que exige ação.</p></div><div className="topbar-user">{usuario.nome}</div></header>
    {mensagem && <div className="system-message">{mensagem}</div>}
    <section className="nexo-central-head"><div className={`nexo-central-health score-${cls.nivel}`}><span>Saúde operacional</span><strong>{saude}</strong><small>{cls.emoji} {cls.label}</small></div><div><h2>{saude >= 80 ? 'Operação sob controle' : saude >= 70 ? 'Atenção aos gargalos' : 'Existem problemas que precisam de ação'}</h2><p>Primeiro mostramos o problema; depois os números.</p></div></section>
    <section className="cards-grid nexo-five-cards"><div className="status-card"><span className="card-label">Minhas atividades</span><strong className="card-value">{resumo.atividades}</strong></div><div className="status-card"><span className="card-label">Demandas</span><strong className="card-value">{resumo.demandas}</strong></div><div className="status-card"><span className="card-label">Atrasadas</span><strong className="card-value">{resumo.atrasadas}</strong></div><div className="status-card"><span className="card-label">Bloqueadas</span><strong className="card-value">{resumo.bloqueadas}</strong></div><div className="status-card"><span className="card-label">Aguardando</span><strong className="card-value">{resumo.aguardando}</strong></div></section>
    <section className="panel"><div className="panel-header"><h3>Onde precisamos agir agora?</h3><p>Problemas que merecem atenção primeiro.</p></div><div className="nexo-problem-list">{problemas.length === 0 ? <div className="empty-state">Nenhum problema crítico.</div> : problemas.map((p) => <div className={`nexo-problem-card severity-${p.gravidade}`} key={p.id}><div className="nexo-problem-icon">{p.gravidade===4?'🔴':p.gravidade===3?'🟠':'🟡'}</div><div className="nexo-problem-main"><strong>{p.titulo}</strong><span>{p.setor} • {p.processo}</span><p><b>Motivo:</b> {p.motivo}</p><p><b>Responsável:</b> {p.pessoa}</p><p><b>Próxima ação:</b> {p.proximaAcao}</p></div><div className="nexo-problem-status">{p.status.replaceAll('_',' ')}</div></div>)}</div></section>
    <section className="nexo-quick-actions"><button onClick={()=>navegar('indicadores')}>Ver indicadores completos</button><button onClick={()=>navegar('operacoes')}>Abrir operações</button><button onClick={()=>navegar('demandas')}>Abrir demandas</button><button onClick={()=>navegar('pessoas-geral')}>Ver equipe</button></section>
  </>
}
NEXO_EOF

MARKER='NEXO - GESTAO 2.0'
if ! grep -q "$MARKER" src/App.css; then
cat >> src/App.css <<'NEXO_EOF'

/* NEXO - GESTAO 2.0 */
.nexo-filter-bar{display:flex;gap:14px;align-items:end;flex-wrap:wrap;margin-bottom:18px}.nexo-filter-bar>div{display:flex;flex-direction:column;gap:6px;min-width:180px}.nexo-filter-bar label{font-size:12px;font-weight:700;color:#6b7280}.nexo-filter-bar select{border:1px solid #d1d5db;border-radius:8px;padding:9px 10px;background:#fff}.nexo-health-hero,.nexo-central-head{display:grid;grid-template-columns:210px 1fr;gap:22px;align-items:center;background:#fff;border:1px solid #e5e7eb;border-radius:12px;padding:20px 22px;margin-bottom:20px}.nexo-health-hero>div:first-child,.nexo-central-health{display:flex;flex-direction:column;align-items:center;justify-content:center;border-radius:12px;padding:16px;background:#f9fafb}.nexo-health-hero strong,.nexo-central-health strong{font-size:48px;line-height:1}.nexo-health-hero span,.nexo-central-health span{font-size:12px;color:#6b7280;margin-bottom:8px}.nexo-health-hero small,.nexo-central-health small{margin-top:8px;font-weight:700}.nexo-health-copy h2,.nexo-central-head h2{margin:0 0 8px}.nexo-health-copy p,.nexo-central-head p{margin:0;color:#6b7280}.nexo-problem-list{display:grid;gap:10px;padding:0 22px 22px}.nexo-problem-card{display:grid;grid-template-columns:34px 1fr auto;gap:12px;align-items:start;border:1px solid #e5e7eb;border-left-width:5px;border-radius:10px;padding:14px;background:#fff}.nexo-problem-card.severity-4{border-left-color:#b91c1c}.nexo-problem-card.severity-3{border-left-color:#c2410c}.nexo-problem-card.severity-2{border-left-color:#ca8a04}.nexo-problem-icon{font-size:20px}.nexo-problem-main{display:flex;flex-direction:column;gap:4px}.nexo-problem-main>span{font-size:12px;color:#6b7280}.nexo-problem-main p{margin:2px 0;font-size:13px;color:#374151}.nexo-problem-status{font-size:11px;font-weight:800;color:#6b7280;background:#f3f4f6;border-radius:999px;padding:6px 9px;white-space:nowrap}.nexo-two-columns{display:grid;grid-template-columns:1fr 1fr;gap:18px;margin-bottom:18px}.nexo-bars{padding:0 22px 22px;display:grid;gap:16px}.nexo-bar-row{display:grid;gap:6px}.nexo-bar-label{display:flex;justify-content:space-between;gap:12px;font-size:13px}.nexo-bar-track{height:10px;border-radius:999px;background:#eef0f2;overflow:hidden}.nexo-bar-fill{height:100%;border-radius:999px;background:currentColor;opacity:.72}.nexo-bar-row small{color:#6b7280}.nexo-score-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;padding:0 22px 22px}.nexo-score-card{border:1px solid #e5e7eb;border-radius:10px;padding:14px;background:#fff}.nexo-score-card>div{display:flex;align-items:center;gap:8px}.nexo-score-card>div strong{font-size:28px}.nexo-score-card h4{margin:10px 0 4px}.nexo-score-card p{margin:0 0 8px;font-size:13px}.nexo-score-card small{color:#6b7280}.nexo-score-pill{display:inline-flex;align-items:center;gap:5px;padding:5px 9px;border-radius:999px;font-weight:800;font-size:12px}.score-excelente,.score-bom{background:#ecfdf5;color:#166534}.score-atencao{background:#fefce8;color:#854d0e}.score-critico{background:#fff7ed;color:#9a3412}.score-muito-critico{background:#fef2f2;color:#991b1b}.nexo-person-detail{display:grid;grid-template-columns:180px 1.2fr 1.5fr;gap:18px;padding:0 22px 22px}.nexo-score-big{display:flex;flex-direction:column;align-items:center;justify-content:center;background:#f9fafb;border-radius:10px;padding:18px}.nexo-score-big strong{font-size:52px}.nexo-score-big span{font-size:12px;color:#6b7280}.nexo-metric-list{display:grid;grid-template-columns:1fr 1fr;gap:8px}.nexo-metric-list>div{display:flex;justify-content:space-between;gap:8px;border:1px solid #e5e7eb;border-radius:8px;padding:10px}.nexo-metric-list span{font-size:12px;color:#6b7280}.nexo-insight-box{border:1px solid #e5e7eb;border-radius:10px;padding:14px;background:#fbfbfc}.nexo-insight-box h4{margin:0 0 10px}.nexo-insight-box p{font-size:13px;line-height:1.45;color:#374151}.nexo-central-head{grid-template-columns:190px 1fr}.nexo-central-health{border:1px solid #e5e7eb}.nexo-health-hero .score-excelente,.nexo-health-hero .score-bom,.nexo-central-health.score-excelente,.nexo-central-health.score-bom{background:#ecfdf5}.nexo-central-health.score-atencao{background:#fefce8}.nexo-central-health.score-critico{background:#fff7ed}.nexo-central-health.score-muito-critico{background:#fef2f2}@media(max-width:1100px){.nexo-score-grid{grid-template-columns:repeat(2,1fr)}.nexo-person-detail{grid-template-columns:160px 1fr}.nexo-insight-box{grid-column:1/-1}}@media(max-width:760px){.nexo-health-hero,.nexo-central-head,.nexo-two-columns,.nexo-person-detail{grid-template-columns:1fr}.nexo-score-grid{grid-template-columns:1fr}.nexo-problem-card{grid-template-columns:30px 1fr}.nexo-problem-status{grid-column:2}}
NEXO_EOF
fi

npm run build
