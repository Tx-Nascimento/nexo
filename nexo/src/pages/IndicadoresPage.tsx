import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario } from '../types'

type Props = { usuario: DadosUsuario }
type Execucao = { id: string; status: string; data_prevista: string | null; data_inicio: string | null; data_conclusao: string | null; responsavel_id: string | null; operacao_id: string }
type Retrabalho = { id: string; execucao_id: string; status: string; iniciado_em: string; corrigido_em: string | null }
type Bloqueio = { id: string; execucao_id: string; iniciado_em: string; finalizado_em: string | null; ativo: boolean }
type Dependencia = { id: string; execucao_id: string; iniciado_em: string; finalizado_em: string | null; ativo: boolean }
type Pessoa = { id: string; nome: string }

function atrasada(x: Execucao) {
  return !!x.data_prevista && !['CONCLUIDA', 'CANCELADA'].includes(x.status) && new Date(x.data_prevista).getTime() < Date.now()
}

function horasEntre(inicio: string, fim: string | null) {
  return Math.max(0, ((fim ? new Date(fim).getTime() : Date.now()) - new Date(inicio).getTime()) / 3600000)
}

export default function IndicadoresPage({ usuario }: Props) {
  const [execucoes, setExecucoes] = useState<Execucao[]>([])
  const [retrabalhos, setRetrabalhos] = useState<Retrabalho[]>([])
  const [bloqueios, setBloqueios] = useState<Bloqueio[]>([])
  const [dependencias, setDependencias] = useState<Dependencia[]>([])
  const [pessoas, setPessoas] = useState<Pessoa[]>([])
  const [mensagem, setMensagem] = useState('')

  useEffect(() => {
    async function carregar() {
      try {
        const [e, r, b, d, p] = await Promise.all([
          supabase.from('execucoes').select('id,status,data_prevista,data_inicio,data_conclusao,responsavel_id,operacao_id,operacao:operacoes!inner(empresa_id)').eq('operacao.empresa_id', usuario.empresaId),
          supabase.from('retrabalhos').select('id,execucao_id,status,iniciado_em,corrigido_em,execucao:execucoes!inner(operacao:operacoes!inner(empresa_id))').eq('execucao.operacao.empresa_id', usuario.empresaId),
          supabase.from('bloqueios').select('id,execucao_id,iniciado_em,finalizado_em,ativo,execucao:execucoes!inner(operacao:operacoes!inner(empresa_id))').eq('execucao.operacao.empresa_id', usuario.empresaId),
          supabase.from('dependencias').select('id,execucao_id,iniciado_em,finalizado_em,ativo,execucao:execucoes!inner(operacao:operacoes!inner(empresa_id))').eq('execucao.operacao.empresa_id', usuario.empresaId),
          supabase.from('pessoas').select('id,nome').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('nome'),
        ])
        for (const x of [e, r, b, d, p]) if (x.error) throw x.error
        setExecucoes((e.data || []) as Execucao[])
        setRetrabalhos((r.data || []) as Retrabalho[])
        setBloqueios((b.data || []) as Bloqueio[])
        setDependencias((d.data || []) as Dependencia[])
        setPessoas((p.data || []) as Pessoa[])
      } catch (error: any) {
        console.error(error)
        setMensagem(error?.message || 'Erro ao carregar indicadores.')
      }
    }
    carregar()
  }, [usuario.empresaId])

  const kpis = useMemo(() => {
    const concluidas = execucoes.filter((x) => x.status === 'CONCLUIDA')
    const concluidasNoPrazo = concluidas.filter((x) => !x.data_prevista || !x.data_conclusao || new Date(x.data_conclusao) <= new Date(x.data_prevista)).length
    const tempoMedio = concluidas.filter((x) => x.data_inicio && x.data_conclusao).map((x) => horasEntre(x.data_inicio!, x.data_conclusao)).reduce((a, b, _, arr) => a + b / arr.length, 0)
    return {
      total: execucoes.length,
      abertas: execucoes.filter((x) => !['CONCLUIDA', 'CANCELADA'].includes(x.status)).length,
      atrasadas: execucoes.filter(atrasada).length,
      noPrazo: concluidas.length ? Math.round((concluidasNoPrazo / concluidas.length) * 100) : 0,
      retrabalho: retrabalhos.length,
      bloqueiosAtivos: bloqueios.filter((x) => x.ativo).length,
      dependenciasAtivas: dependencias.filter((x) => x.ativo).length,
      tempoMedio: Math.round(tempoMedio * 10) / 10,
      horasBloqueadas: Math.round(bloqueios.reduce((s, x) => s + horasEntre(x.iniciado_em, x.finalizado_em), 0) * 10) / 10,
    }
  }, [execucoes, retrabalhos, bloqueios, dependencias])

  const porPessoa = useMemo(() => pessoas.map((p) => {
    const ex = execucoes.filter((x) => x.responsavel_id === p.id)
    const abertas = ex.filter((x) => !['CONCLUIDA', 'CANCELADA'].includes(x.status))
    const concluidas = ex.filter((x) => x.status === 'CONCLUIDA')
    return { ...p, abertas: abertas.length, atrasadas: abertas.filter(atrasada).length, concluidas: concluidas.length }
  }).filter((x) => x.abertas || x.concluidas), [pessoas, execucoes])

  return (
    <>
      <header className="topbar"><div><h1>Indicadores</h1><p>Prazo, qualidade, fluxo, bloqueios e produtividade.</p></div><div className="topbar-user">{usuario.nome}</div></header>
      {mensagem && <div className="system-message">{mensagem}</div>}
      <section className="cards-grid nexo-kpi-grid">
        <div className="status-card"><span className="card-label">Em aberto</span><strong className="card-value">{kpis.abertas}</strong></div>
        <div className="status-card"><span className="card-label">Atrasadas</span><strong className="card-value">{kpis.atrasadas}</strong></div>
        <div className="status-card"><span className="card-label">Concluídas no prazo</span><strong className="card-value">{kpis.noPrazo}%</strong></div>
        <div className="status-card"><span className="card-label">Retrabalhos</span><strong className="card-value">{kpis.retrabalho}</strong></div>
        <div className="status-card"><span className="card-label">Bloqueios ativos</span><strong className="card-value">{kpis.bloqueiosAtivos}</strong></div>
        <div className="status-card"><span className="card-label">Dependências ativas</span><strong className="card-value">{kpis.dependenciasAtivas}</strong></div>
        <div className="status-card"><span className="card-label">Tempo médio</span><strong className="card-value">{kpis.tempoMedio}h</strong></div>
        <div className="status-card"><span className="card-label">Horas bloqueadas</span><strong className="card-value">{kpis.horasBloqueadas}h</strong></div>
      </section>
      <section className="panel"><div className="panel-header"><h3>Desempenho por responsável</h3><p>Volume aberto, atrasado e concluído.</p></div><div className="table-wrapper"><table className="operations-table"><thead><tr><th>Pessoa</th><th>Em aberto</th><th>Atrasadas</th><th>Concluídas</th></tr></thead><tbody>{porPessoa.map((p) => <tr key={p.id}><td><strong>{p.nome}</strong></td><td>{p.abertas}</td><td>{p.atrasadas}</td><td>{p.concluidas}</td></tr>)}</tbody></table></div></section>
    </>
  )
}
