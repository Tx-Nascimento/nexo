import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario } from '../types'

type Props = { usuario: DadosUsuario }
type Pessoa = { id: string; nome: string; email: string | null; setor?: { nome: string } | null; cargo?: { nome: string } | null }
type Execucao = { id: string; responsavel_id: string | null; status: string; data_prevista: string | null; percentual_conclusao: number; operacao_id: string }
type Demanda = { id: string; responsavel_id: string | null; status: string; data_prevista: string | null }
type Carga = { pessoa_id: string; tempo_estimado_minutos: number | null; percentual_carga: number | null }
type Resp = { pessoa_id: string; operacao_id: string; papel: string; ativo: boolean }

function normalizarRelacao<T>(valor: T | T[] | null | undefined): T | null {
  if (!valor) return null
  return Array.isArray(valor) ? valor[0] || null : valor
}

function atrasada(data: string | null, status: string) {
  return !!data && !['CONCLUIDA', 'CANCELADA'].includes(status) && new Date(data).getTime() < Date.now()
}

export default function PessoasGeralPage({ usuario }: Props) {
  const [pessoas, setPessoas] = useState<Pessoa[]>([])
  const [execucoes, setExecucoes] = useState<Execucao[]>([])
  const [demandas, setDemandas] = useState<Demanda[]>([])
  const [carga, setCarga] = useState<Carga[]>([])
  const [responsabilidades, setResponsabilidades] = useState<Resp[]>([])
  const [mensagem, setMensagem] = useState('')

  useEffect(() => {
    async function carregar() {
      try {
        const [p, e, d, c, r] = await Promise.all([
          supabase.from('pessoas').select('id,nome,email,setor:setores(nome),cargo:cargos(nome)').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('nome'),
          supabase.from('execucoes').select('id,responsavel_id,status,data_prevista,percentual_conclusao,operacao_id,operacao:operacoes!inner(empresa_id)').eq('operacao.empresa_id', usuario.empresaId),
          supabase.from('demandas').select('id,responsavel_id,status,data_prevista').eq('empresa_id', usuario.empresaId),
          supabase.from('carga_trabalho').select('pessoa_id,tempo_estimado_minutos,percentual_carga,pessoa:pessoas!inner(empresa_id)').eq('pessoa.empresa_id', usuario.empresaId),
          supabase.from('operacao_responsaveis').select('pessoa_id,operacao_id,papel,ativo,operacao:operacoes!inner(empresa_id)').eq('operacao.empresa_id', usuario.empresaId).eq('ativo', true),
        ])
        for (const x of [p, e, d, c, r]) if (x.error) throw x.error
        setPessoas(
          (p.data || []).map((item: any) => ({
            ...item,
            setor: normalizarRelacao(item.setor),
            cargo: normalizarRelacao(item.cargo),
          })) as Pessoa[]
        )
        setExecucoes((e.data || []) as Execucao[])
        setDemandas((d.data || []) as Demanda[])
        setCarga((c.data || []) as Carga[])
        setResponsabilidades((r.data || []) as Resp[])
      } catch (error: any) {
        console.error(error)
        setMensagem(error?.message || 'Erro ao carregar pessoas.')
      }
    }
    carregar()
  }, [usuario.empresaId])

  const linhas = useMemo(() => pessoas.map((pessoa) => {
    const ex = execucoes.filter((x) => x.responsavel_id === pessoa.id && !['CONCLUIDA', 'CANCELADA'].includes(x.status))
    const dem = demandas.filter((x) => x.responsavel_id === pessoa.id && !['CONCLUIDA', 'CANCELADA'].includes(x.status))
    const cargas = carga.filter((x) => x.pessoa_id === pessoa.id)
    const respons = responsabilidades.filter((x) => x.pessoa_id === pessoa.id)
    return {
      ...pessoa,
      responsabilidades: respons.length,
      atividades: ex.length,
      demandas: dem.length,
      atrasadas: ex.filter((x) => atrasada(x.data_prevista, x.status)).length + dem.filter((x) => atrasada(x.data_prevista, x.status)).length,
      bloqueadas: ex.filter((x) => x.status === 'BLOQUEADA').length,
      minutos: cargas.reduce((s, x) => s + (x.tempo_estimado_minutos || 0), 0),
      cargaPercentual: Math.round(cargas.reduce((s, x) => s + (Number(x.percentual_carga) || 0), 0)),
    }
  }), [pessoas, execucoes, demandas, carga, responsabilidades])

  return (
    <>
      <header className="topbar"><div><h1>Pessoas</h1><p>Responsabilidades, carga e atuação operacional.</p></div><div className="topbar-user">{usuario.nome}</div></header>
      {mensagem && <div className="system-message">{mensagem}</div>}
      <section className="panel">
        <div className="panel-header"><h3>Visão de capacidade</h3><p>Quem está com demanda, atraso, bloqueio e responsabilidades fixas.</p></div>
        <div className="table-wrapper">
          <table className="operations-table">
            <thead><tr><th>Pessoa</th><th>Setor / Cargo</th><th>Responsabilidades</th><th>Atividades</th><th>Demandas</th><th>Atrasadas</th><th>Bloqueadas</th><th>Carga</th></tr></thead>
            <tbody>
              {linhas.map((item) => (
                <tr key={item.id}>
                  <td><strong>{item.nome}</strong><div className="nexo-muted">{item.email || ''}</div></td>
                  <td>{item.setor?.nome || '-'} / {item.cargo?.nome || '-'}</td>
                  <td>{item.responsabilidades}</td><td>{item.atividades}</td><td>{item.demandas}</td>
                  <td>{item.atrasadas}</td><td>{item.bloqueadas}</td>
                  <td>{item.cargaPercentual ? `${item.cargaPercentual}%` : `${item.minutos} min`}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  )
}
