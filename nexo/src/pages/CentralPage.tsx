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
