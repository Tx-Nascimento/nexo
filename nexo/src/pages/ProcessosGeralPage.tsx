import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario } from '../types'

type Props = { usuario: DadosUsuario }

type Processo = { id: string; nome: string; descricao: string | null; setor?: { nome: string } | null }
type Operacao = { id: string; processo_id: string; nome: string; prioridade: string; ativo: boolean }
type Execucao = { id: string; operacao_id: string; status: string; data_prevista: string | null; percentual_conclusao: number }

type Responsabilidade = { operacao_id: string; pessoa?: { nome: string } | null; papel: string; principal: boolean; ativo: boolean }

function normalizarRelacao<T>(valor: T | T[] | null | undefined): T | null {
  if (!valor) return null
  return Array.isArray(valor) ? valor[0] || null : valor
}

function atrasada(x: Execucao) {
  return !!x.data_prevista && !['CONCLUIDA', 'CANCELADA'].includes(x.status) && new Date(x.data_prevista).getTime() < Date.now()
}

export default function ProcessosGeralPage({ usuario }: Props) {
  const [processos, setProcessos] = useState<Processo[]>([])
  const [operacoes, setOperacoes] = useState<Operacao[]>([])
  const [execucoes, setExecucoes] = useState<Execucao[]>([])
  const [responsabilidades, setResponsabilidades] = useState<Responsabilidade[]>([])
  const [selecionado, setSelecionado] = useState<string>('')
  const [mensagem, setMensagem] = useState('')

  useEffect(() => {
    async function carregar() {
      try {
        const [p, o, e, r] = await Promise.all([
          supabase.from('processos').select('id,nome,descricao,setor:setores(nome)').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('nome'),
          supabase.from('operacoes').select('id,processo_id,nome,prioridade,ativo').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('nome'),
          supabase.from('execucoes').select('id,operacao_id,status,data_prevista,percentual_conclusao,operacao:operacoes!inner(empresa_id)').eq('operacao.empresa_id', usuario.empresaId),
          supabase.from('operacao_responsaveis').select('operacao_id,papel,principal,ativo,pessoa:pessoas(nome),operacao:operacoes!inner(empresa_id)').eq('operacao.empresa_id', usuario.empresaId).eq('ativo', true),
        ])
        for (const x of [p, o, e, r]) if (x.error) throw x.error
        setProcessos(
          (p.data || []).map((item: any) => ({
            ...item,
            setor: normalizarRelacao(item.setor),
          })) as Processo[]
        )
        setOperacoes((o.data || []) as Operacao[])
        setExecucoes((e.data || []) as Execucao[])
        setResponsabilidades(
          (r.data || []).map((item: any) => ({
            ...item,
            pessoa: normalizarRelacao(item.pessoa),
          })) as Responsabilidade[]
        )
      } catch (error: any) {
        console.error(error)
        setMensagem(error?.message || 'Erro ao carregar processos.')
      }
    }
    carregar()
  }, [usuario.empresaId])

  const linhas = useMemo(() => processos.map((processo) => {
    const ops = operacoes.filter((o) => o.processo_id === processo.id)
    const ids = new Set(ops.map((o) => o.id))
    const ex = execucoes.filter((x) => ids.has(x.operacao_id))
    const abertas = ex.filter((x) => !['CONCLUIDA', 'CANCELADA'].includes(x.status))
    const progresso = abertas.length ? Math.round(abertas.reduce((s, x) => s + x.percentual_conclusao, 0) / abertas.length) : 0
    return {
      ...processo,
      operacoes: ops.length,
      abertas: abertas.length,
      atrasadas: abertas.filter(atrasada).length,
      bloqueadas: abertas.filter((x) => x.status === 'BLOQUEADA').length,
      progresso,
    }
  }), [processos, operacoes, execucoes])

  const processoAtual = linhas.find((x) => x.id === selecionado)
  const operacoesAtuais = operacoes.filter((x) => x.processo_id === selecionado)

  return (
    <>
      <header className="topbar"><div><h1>Processos</h1><p>Visão operacional de processo → operação → execução.</p></div><div className="topbar-user">{usuario.nome}</div></header>
      {mensagem && <div className="system-message">{mensagem}</div>}
      <section className="panel">
        <div className="panel-header"><h3>Mapa de processos</h3><p>Onde existem atividades, atraso, bloqueio e carga operacional.</p></div>
        <div className="table-wrapper">
          <table className="operations-table">
            <thead><tr><th>Processo</th><th>Setor</th><th>Operações</th><th>Em aberto</th><th>Atrasadas</th><th>Bloqueadas</th><th>Progresso</th><th></th></tr></thead>
            <tbody>
              {linhas.map((item) => (
                <tr key={item.id}>
                  <td><strong>{item.nome}</strong></td>
                  <td>{item.setor?.nome || '-'}</td>
                  <td>{item.operacoes}</td><td>{item.abertas}</td><td>{item.atrasadas}</td><td>{item.bloqueadas}</td><td>{item.progresso}%</td>
                  <td><button className="table-action-button" onClick={() => setSelecionado(item.id)}>Detalhar</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {processoAtual && (
        <section className="panel">
          <div className="panel-header"><h3>{processoAtual.nome}</h3><p>{processoAtual.descricao || 'Sem descrição cadastrada.'}</p></div>
          <div className="nexo-grid-cards">
            {operacoesAtuais.map((op) => {
              const ex = execucoes.filter((x) => x.operacao_id === op.id && !['CONCLUIDA', 'CANCELADA'].includes(x.status))
              const resp = responsabilidades.filter((x) => x.operacao_id === op.id && x.ativo)
              return (
                <div className="nexo-info-card" key={op.id}>
                  <h4>{op.nome}</h4>
                  <p><strong>Prioridade:</strong> {op.prioridade}</p>
                  <p><strong>Em aberto:</strong> {ex.length}</p>
                  <p><strong>Atrasadas:</strong> {ex.filter(atrasada).length}</p>
                  <p><strong>Responsáveis:</strong> {resp.map((x) => x.pessoa?.nome).filter(Boolean).join(', ') || 'Não definidos'}</p>
                </div>
              )
            })}
          </div>
        </section>
      )}
    </>
  )
}
