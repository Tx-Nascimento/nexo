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
    mapa.set(
      'BLOQUEIO',
      (mapa.get('BLOQUEIO') || 0) +
        bloqFiltrados.filter((x) => x.ativo).length
    )
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
