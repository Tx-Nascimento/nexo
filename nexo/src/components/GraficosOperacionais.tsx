export type Serie = { nome: string; valor: number; entradas?: number; atrasadas?: number }
const cores = ['#285ee1','#119b88','#ec9834','#865bd9','#d65b72','#577d96','#a07b34']
const nome = (s: string) => s.toLowerCase().replaceAll('_', ' ')
export function GraficoFluxo({ dados }: { dados: Serie[] }) {
  const max = Math.max(1, ...dados.flatMap(d => [d.valor, d.entradas || 0]))
  const x = (i: number) => 48 + i * 570 / Math.max(1, dados.length - 1)
  const y = (v: number) => 210 - v / max * 160
  const linha = (campo: 'valor' | 'entradas') => dados.map((d, i) => `${x(i)},${y(d[campo] || 0)}`).join(' ')
  const totalEntrada = dados.reduce((n, d) => n + (d.entradas || 0), 0)
  const totalSaida = dados.reduce((n, d) => n + d.valor, 0)
  return <section className="op-card op-chart"><div className="op-chart-heading"><div><p className="op-eyebrow">RITMO DE TRABALHO</p><h2>Entradas × entregas</h2></div><span className="op-chart-unit">Atividades / dia UTC</span></div>
    <div className="op-chart-totals"><span><i style={{ background: cores[0] }} />{totalEntrada} entradas</span><span><i style={{ background: cores[1] }} />{totalSaida} entregas</span></div>
    {!dados.length ? <p>Nenhum registro no período.</p> : <svg viewBox="0 0 650 250" role="img" aria-label={`Atendimento no período: ${totalEntrada} entradas e ${totalSaida} entregas. Valores por dia na tabela abaixo.`}>
      {[0,.25,.5,.75,1].map(v => <g key={v}><line x1="48" x2="618" y1={y(max*v)} y2={y(max*v)} stroke="#e4eaf2" strokeDasharray="4 4"/><text x="35" y={y(max*v)+4} textAnchor="end">{Number((max*v).toFixed(1))}</text></g>)}
      <polyline points={linha('entradas')} fill="none" stroke={cores[0]} strokeWidth="3" strokeLinejoin="round" strokeDasharray="7 4"/>
      <polyline points={linha('valor')} fill="none" stroke={cores[1]} strokeWidth="3" strokeLinejoin="round"/>
      {dados.map((d,i) => <g key={i}><circle cx={x(i)} cy={y(d.valor)} r={dados.length > 35 ? 2 : 3} fill={cores[1]}><title>{d.nome}: {d.valor} entregas / {d.entradas || 0} entradas</title></circle>{(i===0 || i===dados.length-1 || i % Math.max(1,Math.ceil(dados.length/6))===0) && <text x={x(i)} y="237" textAnchor="middle">{d.nome}</text>}</g>)}
    </svg>}
    <p className="op-caption">Mais entradas que entregas? Verifique se a carteira está se acumulando.</p><details><summary>Ver valores por dia</summary><div className="op-table-wrap"><table><thead><tr><th>Dia UTC</th><th>Entradas</th><th>Entregas</th></tr></thead><tbody>{dados.map((d,i)=><tr key={i}><td>{d.nome}</td><td>{d.entradas || 0}</td><td>{d.valor}</td></tr>)}</tbody></table></div></details>
  </section>
}
export function GraficoEtapas({ dados }: { dados: Serie[] }) {
  const total = dados.reduce((n,d)=>n+d.valor,0)
  let anterior = 0
  const segmentos = dados.map((d,i)=>{ const inicio=anterior; anterior+= total ? d.valor/total*100 : 0; return `${cores[i%cores.length]} ${inicio}% ${anterior}%` })
  return <section className="op-card op-chart"><p className="op-eyebrow">SITUAÇÃO ATUAL</p><h2>Onde está o trabalho?</h2><div className="op-donut-layout"><div className="op-donut" role="img" aria-label={`${total} atividades abertas. ${dados.map(d=>`${nome(d.nome)}: ${d.valor}`).join('; ')}`} style={{background:total ? `conic-gradient(${segmentos.join(',')})` : '#e6ebf2'}}><div><strong>{total}</strong><span>em aberto</span></div></div><ul className="op-chart-legend">{dados.map((d,i)=><li key={d.nome}><i style={{background:cores[i%cores.length]}}/><span>{nome(d.nome)}</span><strong>{d.valor}</strong></li>)}{!total && <li>Sem atividades abertas.</li>}</ul></div><p className="op-caption">Cada atividade aparece em uma única etapa.</p></section>
}
